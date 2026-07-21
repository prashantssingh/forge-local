package main

import (
	"fmt"
	"net"
	"net/url"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

type Config struct {
	Address        string
	OllamaURL      string
	Model          string
	ContextSize    int
	Reasoning      string
	DataDir        string
	MaxAgents      int
	MemoryItems    int
	APIKey         string
	RequestMaxBody int64
}

func LoadConfig() (Config, error) {
	contextSize, err := envInt("BRAIN_CONTEXT_SIZE", 8192)
	if err != nil {
		return Config{}, err
	}
	maxAgents, err := envInt("BRAIN_MAX_AGENTS", 3)
	if err != nil {
		return Config{}, err
	}
	memoryItems, err := envInt("BRAIN_MEMORY_ITEMS", 8)
	if err != nil {
		return Config{}, err
	}

	dataDir := envString("BRAIN_DATA_DIR", "./data")
	dataDir, err = filepath.Abs(dataDir)
	if err != nil {
		return Config{}, fmt.Errorf("resolve BRAIN_DATA_DIR: %w", err)
	}

	cfg := Config{
		Address:        envString("BRAIN_ADDRESS", "127.0.0.1:8080"),
		OllamaURL:      strings.TrimRight(envString("OLLAMA_URL", "http://127.0.0.1:11434"), "/"),
		Model:          envString("BRAIN_MODEL", "gpt-oss:20b"),
		ContextSize:    contextSize,
		Reasoning:      envString("BRAIN_REASONING", "high"),
		DataDir:        dataDir,
		MaxAgents:      maxAgents,
		MemoryItems:    memoryItems,
		APIKey:         os.Getenv("BRAIN_API_KEY"),
		RequestMaxBody: 1 << 20,
	}

	if err := cfg.Validate(); err != nil {
		return Config{}, err
	}
	return cfg, nil
}

func (c Config) Validate() error {
	if c.Model == "" {
		return fmt.Errorf("BRAIN_MODEL cannot be empty")
	}
	if c.ContextSize < 2048 || c.ContextSize > 32768 {
		return fmt.Errorf("BRAIN_CONTEXT_SIZE must be between 2048 and 32768")
	}
	if c.MaxAgents < 1 || c.MaxAgents > 5 {
		return fmt.Errorf("BRAIN_MAX_AGENTS must be between 1 and 5")
	}
	if c.MemoryItems < 1 || c.MemoryItems > 20 {
		return fmt.Errorf("BRAIN_MEMORY_ITEMS must be between 1 and 20")
	}
	if c.Reasoning != "low" && c.Reasoning != "medium" && c.Reasoning != "high" {
		return fmt.Errorf("BRAIN_REASONING must be low, medium, or high")
	}

	u, err := url.Parse(c.OllamaURL)
	if err != nil || u.Host == "" || (u.Scheme != "http" && u.Scheme != "https") {
		return fmt.Errorf("OLLAMA_URL must be an http or https URL")
	}

	host, _, err := net.SplitHostPort(c.Address)
	if err != nil {
		return fmt.Errorf("BRAIN_ADDRESS must be host:port: %w", err)
	}
	if c.APIKey == "" && !isLoopbackHost(host) {
		return fmt.Errorf("BRAIN_API_KEY is required when BRAIN_ADDRESS is not loopback")
	}
	return nil
}

func isLoopbackHost(host string) bool {
	if host == "localhost" {
		return true
	}
	ip := net.ParseIP(host)
	return ip != nil && ip.IsLoopback()
}

func envString(name, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(name)); value != "" {
		return value
	}
	return fallback
}

func envInt(name string, fallback int) (int, error) {
	value := strings.TrimSpace(os.Getenv(name))
	if value == "" {
		return fallback, nil
	}
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return 0, fmt.Errorf("%s must be an integer", name)
	}
	return parsed, nil
}
