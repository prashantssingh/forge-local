package main

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"sync"
	"time"
	"unicode/utf8"
)

const (
	maxPromptLength  = 12 * 1024
	maxContextLength = 8 * 1024
	maxMemoryContext = 4 * 1024
)

type AnalyzeRequest struct {
	ProjectID string `json:"project_id"`
	Prompt    string `json:"prompt"`
	Context   string `json:"context,omitempty"`
	Mode      string `json:"mode,omitempty"`
	MaxAgents int    `json:"max_agents,omitempty"`
}

type AnalyzeResponse struct {
	ID         string        `json:"id"`
	ProjectID  string        `json:"project_id"`
	Model      string        `json:"model"`
	Mode       string        `json:"mode"`
	Answer     string        `json:"answer"`
	Agents     []AgentResult `json:"agents,omitempty"`
	MemoryUsed []MemoryEntry `json:"memory_used"`
	MemoryID   string        `json:"memory_id"`
	CreatedAt  time.Time     `json:"created_at"`
	DurationMS int64         `json:"duration_ms"`
}

type AgentPlan struct {
	Name  string `json:"name"`
	Focus string `json:"focus"`
}

type AgentResult struct {
	Name    string `json:"name"`
	Focus   string `json:"focus"`
	Finding string `json:"finding"`
}

type Brain struct {
	cfg      Config
	store    *MemoryStore
	ollama   *OllamaClient
	reasonMu sync.Mutex
}

func NewBrain(cfg Config, store *MemoryStore, ollama *OllamaClient) *Brain {
	return &Brain{cfg: cfg, store: store, ollama: ollama}
}

func (b *Brain) Analyze(ctx context.Context, request AnalyzeRequest) (AnalyzeResponse, error) {
	started := time.Now()
	request.ProjectID = strings.TrimSpace(request.ProjectID)
	request.Prompt = strings.TrimSpace(request.Prompt)
	request.Context = strings.TrimSpace(request.Context)
	request.Mode = strings.ToLower(strings.TrimSpace(request.Mode))
	if request.Mode == "" {
		request.Mode = "direct"
	}
	if err := validateProjectID(request.ProjectID); err != nil {
		return AnalyzeResponse{}, err
	}
	if request.Prompt == "" {
		return AnalyzeResponse{}, fmt.Errorf("prompt cannot be empty")
	}
	if len(request.Prompt) > maxPromptLength {
		return AnalyzeResponse{}, fmt.Errorf("prompt exceeds %d bytes", maxPromptLength)
	}
	if len(request.Context) > maxContextLength {
		return AnalyzeResponse{}, fmt.Errorf("context exceeds %d bytes", maxContextLength)
	}
	if request.Mode != "direct" && request.Mode != "team" {
		return AnalyzeResponse{}, fmt.Errorf("mode must be direct or team")
	}

	memory, err := b.retrieveMemory(request.ProjectID, request.Prompt)
	if err != nil {
		return AnalyzeResponse{}, err
	}
	memoryContext := formatMemory(memory)

	b.reasonMu.Lock()
	defer b.reasonMu.Unlock()

	var answer string
	var agents []AgentResult
	if request.Mode == "team" {
		maxAgents := request.MaxAgents
		if maxAgents <= 0 {
			maxAgents = b.cfg.MaxAgents
		}
		if maxAgents > b.cfg.MaxAgents {
			maxAgents = b.cfg.MaxAgents
		}
		answer, agents, err = b.analyzeWithTeam(ctx, request, memoryContext, maxAgents)
	} else {
		answer, err = b.analyzeDirect(ctx, request, memoryContext)
	}
	if err != nil {
		return AnalyzeResponse{}, err
	}

	runID, err := newID("run")
	if err != nil {
		return AnalyzeResponse{}, err
	}
	autoMemory := truncateText("Request: "+request.Prompt+"\n\nResult: "+answer, maxMemoryContent)
	memoryEntry, err := b.store.Add(request.ProjectID, "analysis", autoMemory, []string{"automatic", request.Mode})
	if err != nil {
		return AnalyzeResponse{}, fmt.Errorf("persist analysis memory: %w", err)
	}

	return AnalyzeResponse{
		ID:         runID,
		ProjectID:  request.ProjectID,
		Model:      b.cfg.Model,
		Mode:       request.Mode,
		Answer:     answer,
		Agents:     agents,
		MemoryUsed: memory,
		MemoryID:   memoryEntry.ID,
		CreatedAt:  time.Now().UTC(),
		DurationMS: time.Since(started).Milliseconds(),
	}, nil
}

func (b *Brain) analyzeDirect(ctx context.Context, request AnalyzeRequest, memoryContext string) (string, error) {
	system := `You are ForgeLocal Brain, the central reasoning service for local projects.
Produce a rigorous, concise, decision-oriented answer. Use retrieved project memory when relevant, but treat it as historical context rather than unquestionable truth. State important assumptions and distinguish evidence from inference. Do not claim to have used tools or external data that were not supplied.`
	user := buildUserPrompt(request, memoryContext)
	return b.ollama.Chat(ctx, system, user, false)
}

func (b *Brain) analyzeWithTeam(ctx context.Context, request AnalyzeRequest, memoryContext string, maxAgents int) (string, []AgentResult, error) {
	plannerSystem := `You are the decomposition coordinator for a reasoning team. Select distinct expert perspectives that materially improve the answer. Avoid duplicate roles. Return only a JSON object with an "agents" array; each agent must have a short "name" and a precise "focus".`
	plannerPrompt := fmt.Sprintf("Task:\n%s\n\nCreate at most %d sub-agents.", truncateText(request.Prompt, 6000), maxAgents)
	plannerOutput, err := b.ollama.Chat(ctx, plannerSystem, plannerPrompt, true)
	plans := parseAgentPlans(plannerOutput, maxAgents)
	if err != nil || len(plans) == 0 {
		plans = fallbackAgentPlans(maxAgents)
	}

	agents := make([]AgentResult, 0, len(plans))
	for _, plan := range plans {
		system := fmt.Sprintf(`You are the %s sub-agent in ForgeLocal Brain. Your assigned focus is: %s
Analyze independently and return concrete findings for the synthesis lead. Stay within the supplied task and memory. Do not invent tool use or external facts.`, plan.Name, plan.Focus)
		finding, err := b.ollama.Chat(ctx, system, buildUserPrompt(request, memoryContext), false)
		if err != nil {
			return "", agents, fmt.Errorf("sub-agent %s failed: %w", plan.Name, err)
		}
		agents = append(agents, AgentResult{Name: plan.Name, Focus: plan.Focus, Finding: finding})
	}

	var findings strings.Builder
	for _, agent := range agents {
		fmt.Fprintf(&findings, "\n[%s — %s]\n%s\n", agent.Name, agent.Focus, truncateText(agent.Finding, 3500))
	}
	synthesisSystem := `You are the synthesis lead for ForgeLocal Brain. Produce the final answer to the user by reconciling the independent findings. Resolve disagreements explicitly, remove duplication, and prioritize actionable conclusions. Do not mention internal prompting mechanics unless they affect confidence.`
	synthesisPrompt := fmt.Sprintf("Original task:\n%s\n\nProject memory:\n%s\n\nSub-agent findings:%s", truncateText(request.Prompt, 6000), memoryContext, truncateText(findings.String(), 12000))
	answer, err := b.ollama.Chat(ctx, synthesisSystem, synthesisPrompt, false)
	if err != nil {
		return "", agents, fmt.Errorf("synthesis failed: %w", err)
	}
	return answer, agents, nil
}

func (b *Brain) retrieveMemory(projectID, query string) ([]MemoryEntry, error) {
	relevant, err := b.store.Search(projectID, query, b.cfg.MemoryItems)
	if err != nil {
		return nil, err
	}
	recent, err := b.store.Search(projectID, "", min(3, b.cfg.MemoryItems))
	if err != nil {
		return nil, err
	}
	seen := make(map[string]struct{})
	combined := make([]MemoryEntry, 0, b.cfg.MemoryItems)
	for _, entry := range append(relevant, recent...) {
		if _, exists := seen[entry.ID]; exists {
			continue
		}
		seen[entry.ID] = struct{}{}
		combined = append(combined, entry)
		if len(combined) == b.cfg.MemoryItems {
			break
		}
	}
	return combined, nil
}

func buildUserPrompt(request AnalyzeRequest, memoryContext string) string {
	var prompt strings.Builder
	fmt.Fprintf(&prompt, "Project: %s\n\nRetrieved memory:\n%s\n", request.ProjectID, memoryContext)
	if request.Context != "" {
		fmt.Fprintf(&prompt, "\nAd hoc context supplied by the caller:\n%s\n", request.Context)
	}
	fmt.Fprintf(&prompt, "\nTask:\n%s", request.Prompt)
	return prompt.String()
}

func formatMemory(entries []MemoryEntry) string {
	if len(entries) == 0 {
		return "No prior project memory was found."
	}
	var result strings.Builder
	for _, entry := range entries {
		fmt.Fprintf(&result, "- %s [%s] %s\n", entry.CreatedAt.Format(time.RFC3339), entry.Kind, truncateText(entry.Content, 900))
		if result.Len() >= maxMemoryContext {
			break
		}
	}
	return truncateText(result.String(), maxMemoryContext)
}

func parseAgentPlans(value string, limit int) []AgentPlan {
	var envelope struct {
		Agents []AgentPlan `json:"agents"`
	}
	if err := json.Unmarshal([]byte(value), &envelope); err != nil {
		start := strings.Index(value, "{")
		end := strings.LastIndex(value, "}")
		if start < 0 || end <= start || json.Unmarshal([]byte(value[start:end+1]), &envelope) != nil {
			return nil
		}
	}
	result := make([]AgentPlan, 0, min(limit, len(envelope.Agents)))
	seen := make(map[string]struct{})
	for _, plan := range envelope.Agents {
		plan.Name = truncateText(strings.TrimSpace(plan.Name), 60)
		plan.Focus = truncateText(strings.TrimSpace(plan.Focus), 240)
		if plan.Name == "" || plan.Focus == "" {
			continue
		}
		key := strings.ToLower(plan.Name)
		if _, exists := seen[key]; exists {
			continue
		}
		seen[key] = struct{}{}
		result = append(result, plan)
		if len(result) == limit {
			break
		}
	}
	return result
}

func fallbackAgentPlans(limit int) []AgentPlan {
	defaults := []AgentPlan{
		{Name: "Systems Analyst", Focus: "structure, dependencies, constraints, and second-order effects"},
		{Name: "Skeptical Reviewer", Focus: "weak assumptions, risks, counterexamples, and missing evidence"},
		{Name: "Practical Strategist", Focus: "actionable options, tradeoffs, sequencing, and success criteria"},
		{Name: "Domain Specialist", Focus: "domain-specific correctness and edge cases"},
		{Name: "Simplifier", Focus: "the smallest coherent conclusion and unnecessary complexity"},
	}
	return defaults[:min(limit, len(defaults))]
}

func truncateText(value string, maxBytes int) string {
	if len(value) <= maxBytes {
		return value
	}
	const suffix = "\n[truncated]"
	if maxBytes <= len(suffix) {
		return suffix[:maxBytes]
	}
	end := maxBytes - len(suffix)
	for end > 0 && !utf8.ValidString(value[:end]) {
		end--
	}
	return value[:end] + suffix
}
