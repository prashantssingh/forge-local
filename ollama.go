package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

type OllamaClient struct {
	baseURL     string
	model       string
	contextSize int
	reasoning   string
	httpClient  *http.Client
}

type ollamaChatRequest struct {
	Model     string          `json:"model"`
	Messages  []ollamaMessage `json:"messages"`
	Stream    bool            `json:"stream"`
	Think     string          `json:"think"`
	KeepAlive string          `json:"keep_alive"`
	Format    string          `json:"format,omitempty"`
	Options   ollamaOptions   `json:"options"`
}

type ollamaMessage struct {
	Role     string `json:"role"`
	Content  string `json:"content"`
	Thinking string `json:"thinking,omitempty"`
}

type ollamaOptions struct {
	NumCtx      int     `json:"num_ctx"`
	Temperature float64 `json:"temperature"`
}

type ollamaChatResponse struct {
	Message ollamaMessage `json:"message"`
	Done    bool          `json:"done"`
	Error   string        `json:"error,omitempty"`
}

func NewOllamaClient(cfg Config) *OllamaClient {
	return &OllamaClient{
		baseURL:     cfg.OllamaURL,
		model:       cfg.Model,
		contextSize: cfg.ContextSize,
		reasoning:   cfg.Reasoning,
		httpClient: &http.Client{
			Timeout: 15 * time.Minute,
		},
	}
}

func (c *OllamaClient) Chat(ctx context.Context, system, user string, jsonMode bool) (string, error) {
	request := ollamaChatRequest{
		Model: c.model,
		Messages: []ollamaMessage{
			{Role: "system", Content: system},
			{Role: "user", Content: user},
		},
		Stream:    false,
		Think:     c.reasoning,
		KeepAlive: "30m",
		Options: ollamaOptions{
			NumCtx:      c.contextSize,
			Temperature: 0.2,
		},
	}
	if jsonMode {
		request.Format = "json"
	}

	body, err := json.Marshal(request)
	if err != nil {
		return "", fmt.Errorf("encode Ollama request: %w", err)
	}
	httpRequest, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/api/chat", bytes.NewReader(body))
	if err != nil {
		return "", fmt.Errorf("create Ollama request: %w", err)
	}
	httpRequest.Header.Set("Content-Type", "application/json")

	response, err := c.httpClient.Do(httpRequest)
	if err != nil {
		return "", fmt.Errorf("call Ollama: %w", err)
	}
	defer response.Body.Close()

	if response.StatusCode < 200 || response.StatusCode >= 300 {
		message, _ := io.ReadAll(io.LimitReader(response.Body, 8*1024))
		return "", fmt.Errorf("Ollama returned %s: %s", response.Status, string(message))
	}
	var result ollamaChatResponse
	if err := json.NewDecoder(io.LimitReader(response.Body, 8*1024*1024)).Decode(&result); err != nil {
		return "", fmt.Errorf("decode Ollama response: %w", err)
	}
	if result.Error != "" {
		return "", fmt.Errorf("Ollama error: %s", result.Error)
	}
	if result.Message.Content == "" {
		return "", fmt.Errorf("Ollama returned an empty answer")
	}
	return result.Message.Content, nil
}

func (c *OllamaClient) Check(ctx context.Context) error {
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/api/tags", nil)
	if err != nil {
		return err
	}
	response, err := c.httpClient.Do(request)
	if err != nil {
		return err
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return fmt.Errorf("Ollama returned %s", response.Status)
	}
	return nil
}
