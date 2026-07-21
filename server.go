package main

import (
	"context"
	"crypto/subtle"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"
)

type APIServer struct {
	cfg   Config
	brain *Brain
	store *MemoryStore
}

type MemoryRequest struct {
	ProjectID string   `json:"project_id"`
	Kind      string   `json:"kind"`
	Content   string   `json:"content"`
	Tags      []string `json:"tags,omitempty"`
}

type errorResponse struct {
	Error string `json:"error"`
}

func NewAPIServer(cfg Config, brain *Brain, store *MemoryStore) *APIServer {
	return &APIServer{cfg: cfg, brain: brain, store: store}
}

func (s *APIServer) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/health", s.handleHealth)
	mux.HandleFunc("/v1/analyze", s.handleAnalyze)
	mux.HandleFunc("/v1/memory", s.handleMemory)
	mux.HandleFunc("/v1/projects", s.handleProjects)
	return s.logRequests(s.authenticate(mux))
}

func (s *APIServer) handleHealth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		methodNotAllowed(w, http.MethodGet)
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 3*time.Second)
	defer cancel()
	ollamaStatus := "ok"
	status := http.StatusOK
	if err := s.brain.ollama.Check(ctx); err != nil {
		ollamaStatus = "unavailable"
		status = http.StatusServiceUnavailable
	}
	writeJSON(w, status, map[string]any{
		"status":        map[bool]string{true: "ok", false: "degraded"}[status == http.StatusOK],
		"ollama":        ollamaStatus,
		"model":         s.cfg.Model,
		"reasoning":     s.cfg.Reasoning,
		"context_size":  s.cfg.ContextSize,
		"max_subagents": s.cfg.MaxAgents,
	})
}

func (s *APIServer) handleAnalyze(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		methodNotAllowed(w, http.MethodPost)
		return
	}
	var request AnalyzeRequest
	if err := s.decodeJSON(w, r, &request); err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	response, err := s.brain.Analyze(r.Context(), request)
	if err != nil {
		writeError(w, statusForError(err), err)
		return
	}
	writeJSON(w, http.StatusOK, response)
}

func (s *APIServer) handleMemory(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodPost:
		var request MemoryRequest
		if err := s.decodeJSON(w, r, &request); err != nil {
			writeError(w, http.StatusBadRequest, err)
			return
		}
		entry, err := s.store.Add(request.ProjectID, request.Kind, request.Content, request.Tags)
		if err != nil {
			writeError(w, http.StatusBadRequest, err)
			return
		}
		writeJSON(w, http.StatusCreated, entry)
	case http.MethodGet:
		projectID := r.URL.Query().Get("project_id")
		limit := 8
		if rawLimit := r.URL.Query().Get("limit"); rawLimit != "" {
			parsed, err := strconv.Atoi(rawLimit)
			if err != nil || parsed < 1 || parsed > 50 {
				writeError(w, http.StatusBadRequest, fmt.Errorf("limit must be between 1 and 50"))
				return
			}
			limit = parsed
		}
		entries, err := s.store.Search(projectID, r.URL.Query().Get("q"), limit)
		if err != nil {
			writeError(w, http.StatusBadRequest, err)
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"entries": entries})
	default:
		methodNotAllowed(w, http.MethodGet+", "+http.MethodPost)
	}
}

func (s *APIServer) handleProjects(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		methodNotAllowed(w, http.MethodGet)
		return
	}
	projects, err := s.store.Projects()
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"projects": projects})
}

func (s *APIServer) decodeJSON(w http.ResponseWriter, r *http.Request, destination any) error {
	if contentType := r.Header.Get("Content-Type"); !strings.HasPrefix(contentType, "application/json") {
		return fmt.Errorf("Content-Type must be application/json")
	}
	r.Body = http.MaxBytesReader(w, r.Body, s.cfg.RequestMaxBody)
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(destination); err != nil {
		return fmt.Errorf("invalid JSON: %w", err)
	}
	var extra any
	if err := decoder.Decode(&extra); !errors.Is(err, io.EOF) {
		return fmt.Errorf("request body must contain exactly one JSON object")
	}
	return nil
}

func (s *APIServer) authenticate(next http.Handler) http.Handler {
	if s.cfg.APIKey == "" {
		return next
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		provided := r.Header.Get("X-API-Key")
		if authorization := r.Header.Get("Authorization"); strings.HasPrefix(authorization, "Bearer ") {
			provided = strings.TrimPrefix(authorization, "Bearer ")
		}
		if subtle.ConstantTimeCompare([]byte(provided), []byte(s.cfg.APIKey)) != 1 {
			writeJSON(w, http.StatusUnauthorized, errorResponse{Error: "unauthorized"})
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (s *APIServer) logRequests(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		started := time.Now()
		next.ServeHTTP(w, r)
		log.Printf("method=%s path=%s duration_ms=%d", r.Method, r.URL.Path, time.Since(started).Milliseconds())
	})
}

func statusForError(err error) int {
	message := err.Error()
	if strings.Contains(message, "cannot be empty") ||
		strings.Contains(message, "must be") ||
		strings.Contains(message, "exceeds") ||
		strings.Contains(message, "project_id") {
		return http.StatusBadRequest
	}
	return http.StatusBadGateway
}

func methodNotAllowed(w http.ResponseWriter, allowed string) {
	w.Header().Set("Allow", allowed)
	writeJSON(w, http.StatusMethodNotAllowed, errorResponse{Error: "method not allowed"})
}

func writeError(w http.ResponseWriter, status int, err error) {
	writeJSON(w, status, errorResponse{Error: err.Error()})
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(value); err != nil {
		log.Printf("encode response: %v", err)
	}
}
