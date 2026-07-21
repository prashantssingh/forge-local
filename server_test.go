package main

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestBrainAPITracksMemoryAndRunsTeam(t *testing.T) {
	cfg := testConfig(t)
	store, err := NewMemoryStore(cfg.DataDir)
	if err != nil {
		t.Fatal(err)
	}
	brain := NewBrain(cfg, store, newFakeOllama(t, cfg))
	handler := NewAPIServer(cfg, brain, store).Handler()

	postJSON(t, handler, "/v1/memory", MemoryRequest{
		ProjectID: "project-one",
		Kind:      "decision",
		Content:   "Prefer a small central API.",
		Tags:      []string{"architecture"},
	}, http.StatusCreated, nil)

	var direct AnalyzeResponse
	postJSON(t, handler, "/v1/analyze", AnalyzeRequest{
		ProjectID: "project-one",
		Prompt:    "What architecture did we choose?",
	}, http.StatusOK, &direct)
	if direct.Answer != "direct answer" || direct.MemoryID == "" || len(direct.MemoryUsed) == 0 {
		t.Fatalf("unexpected direct response: %#v", direct)
	}

	var team AnalyzeResponse
	postJSON(t, handler, "/v1/analyze", AnalyzeRequest{
		ProjectID: "project-one",
		Prompt:    "Analyze the main risks.",
		Mode:      "team",
		MaxAgents: 2,
	}, http.StatusOK, &team)
	if team.Answer != "synthesized answer" || len(team.Agents) != 2 {
		t.Fatalf("unexpected team response: %#v", team)
	}

	request := httptest.NewRequest(http.MethodGet, "/v1/memory?project_id=project-one&q=architecture&limit=10", nil)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != http.StatusOK {
		t.Fatalf("memory search status: %d", response.Code)
	}
	var search struct {
		Entries []MemoryEntry `json:"entries"`
	}
	if err := json.NewDecoder(response.Body).Decode(&search); err != nil {
		t.Fatal(err)
	}
	if len(search.Entries) == 0 {
		t.Fatal("expected retrievable memory")
	}
}

func TestAPIKeyProtectsEndpoints(t *testing.T) {
	cfg := testConfig(t)
	cfg.APIKey = "secret"
	store, err := NewMemoryStore(cfg.DataDir)
	if err != nil {
		t.Fatal(err)
	}
	handler := NewAPIServer(cfg, NewBrain(cfg, store, newFakeOllama(t, cfg)), store).Handler()

	request := httptest.NewRequest(http.MethodGet, "/health", nil)
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != http.StatusUnauthorized {
		t.Fatalf("expected unauthorized, got %d", response.Code)
	}

	request = httptest.NewRequest(http.MethodGet, "/health", nil)
	request.Header.Set("Authorization", "Bearer secret")
	response = httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != http.StatusOK {
		t.Fatalf("expected healthy authenticated response, got %d", response.Code)
	}
}

type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(request *http.Request) (*http.Response, error) {
	return f(request)
}

func newFakeOllama(t *testing.T, cfg Config) *OllamaClient {
	t.Helper()
	client := NewOllamaClient(cfg)
	client.httpClient.Transport = roundTripFunc(func(request *http.Request) (*http.Response, error) {
		var value any
		switch request.URL.Path {
		case "/api/tags":
			value = map[string]any{"models": []any{}}
		case "/api/chat":
			var chatRequest ollamaChatRequest
			if err := json.NewDecoder(request.Body).Decode(&chatRequest); err != nil {
				t.Fatal(err)
			}
			system := chatRequest.Messages[0].Content
			content := "direct answer"
			switch {
			case strings.Contains(system, "decomposition coordinator"):
				content = `{"agents":[{"name":"Risk Analyst","focus":"identify risks"},{"name":"Operator","focus":"identify mitigations"}]}`
			case strings.Contains(system, "sub-agent"):
				content = "independent finding"
			case strings.Contains(system, "synthesis lead"):
				content = "synthesized answer"
			}
			value = ollamaChatResponse{Message: ollamaMessage{Role: "assistant", Content: content}, Done: true}
		default:
			return &http.Response{
				StatusCode: http.StatusNotFound,
				Status:     "404 Not Found",
				Header:     make(http.Header),
				Body:       io.NopCloser(strings.NewReader("not found")),
				Request:    request,
			}, nil
		}

		body, err := json.Marshal(value)
		if err != nil {
			t.Fatal(err)
		}
		return &http.Response{
			StatusCode: http.StatusOK,
			Status:     "200 OK",
			Header:     http.Header{"Content-Type": []string{"application/json"}},
			Body:       io.NopCloser(bytes.NewReader(body)),
			Request:    request,
		}, nil
	})
	return client
}

func testConfig(t *testing.T) Config {
	t.Helper()
	return Config{
		Address:        "127.0.0.1:8080",
		OllamaURL:      "http://ollama.test",
		Model:          "test-model",
		ContextSize:    8192,
		Reasoning:      "high",
		DataDir:        t.TempDir(),
		MaxAgents:      3,
		MemoryItems:    8,
		RequestMaxBody: 1 << 20,
	}
}

func postJSON(t *testing.T, handler http.Handler, target string, value any, expectedStatus int, destination any) {
	t.Helper()
	body, err := json.Marshal(value)
	if err != nil {
		t.Fatal(err)
	}
	request := httptest.NewRequest(http.MethodPost, target, bytes.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	response := httptest.NewRecorder()
	handler.ServeHTTP(response, request)
	if response.Code != expectedStatus {
		t.Fatalf("expected status %d, got %d: %s", expectedStatus, response.Code, response.Body.String())
	}
	if destination != nil {
		if err := json.NewDecoder(response.Body).Decode(destination); err != nil {
			t.Fatal(err)
		}
	}
}
