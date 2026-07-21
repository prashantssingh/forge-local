package main

import (
	"bufio"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"
	"unicode"
)

const (
	maxMemoryContent = 64 * 1024
	maxMemoryTags    = 10
)

var safeNamePattern = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$`)

type MemoryEntry struct {
	ID        string    `json:"id"`
	ProjectID string    `json:"project_id"`
	Kind      string    `json:"kind"`
	Content   string    `json:"content"`
	Tags      []string  `json:"tags,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}

type MemoryStore struct {
	root string
	mu   sync.RWMutex
}

func NewMemoryStore(root string) (*MemoryStore, error) {
	if root == "" {
		return nil, fmt.Errorf("memory root cannot be empty")
	}
	if err := os.MkdirAll(filepath.Join(root, "projects"), 0o700); err != nil {
		return nil, fmt.Errorf("create memory root: %w", err)
	}
	return &MemoryStore{root: root}, nil
}

func (s *MemoryStore) Add(projectID, kind, content string, tags []string) (MemoryEntry, error) {
	if err := validateProjectID(projectID); err != nil {
		return MemoryEntry{}, err
	}
	kind = strings.ToLower(strings.TrimSpace(kind))
	if kind == "" {
		kind = "progress"
	}
	if !validMemoryKind(kind) {
		return MemoryEntry{}, fmt.Errorf("kind must be context, progress, decision, or analysis")
	}
	content = strings.TrimSpace(content)
	if content == "" {
		return MemoryEntry{}, fmt.Errorf("content cannot be empty")
	}
	if len(content) > maxMemoryContent {
		return MemoryEntry{}, fmt.Errorf("content exceeds %d bytes", maxMemoryContent)
	}

	cleanTags, err := validateTags(tags)
	if err != nil {
		return MemoryEntry{}, err
	}
	id, err := newID("mem")
	if err != nil {
		return MemoryEntry{}, err
	}
	entry := MemoryEntry{
		ID:        id,
		ProjectID: projectID,
		Kind:      kind,
		Content:   content,
		Tags:      cleanTags,
		CreatedAt: time.Now().UTC(),
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	dir := s.projectDir(projectID)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return MemoryEntry{}, fmt.Errorf("create project memory directory: %w", err)
	}
	file, err := os.OpenFile(filepath.Join(dir, "memory.jsonl"), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o600)
	if err != nil {
		return MemoryEntry{}, fmt.Errorf("open project memory: %w", err)
	}
	defer file.Close()

	encoded, err := json.Marshal(entry)
	if err != nil {
		return MemoryEntry{}, fmt.Errorf("encode memory entry: %w", err)
	}
	if _, err := file.Write(append(encoded, '\n')); err != nil {
		return MemoryEntry{}, fmt.Errorf("append memory entry: %w", err)
	}
	if err := file.Sync(); err != nil {
		return MemoryEntry{}, fmt.Errorf("sync memory entry: %w", err)
	}
	return entry, nil
}

func (s *MemoryStore) Search(projectID, query string, limit int) ([]MemoryEntry, error) {
	if err := validateProjectID(projectID); err != nil {
		return nil, err
	}
	if limit <= 0 {
		limit = 8
	}
	if limit > 50 {
		limit = 50
	}

	s.mu.RLock()
	entries, err := s.readAll(projectID)
	s.mu.RUnlock()
	if err != nil {
		return nil, err
	}
	if len(entries) == 0 {
		return []MemoryEntry{}, nil
	}

	terms := tokenize(query)
	if len(terms) == 0 {
		reverseEntries(entries)
		if len(entries) > limit {
			entries = entries[:limit]
		}
		return entries, nil
	}

	type scoredEntry struct {
		entry MemoryEntry
		score int
	}
	scored := make([]scoredEntry, 0, len(entries))
	for i, entry := range entries {
		haystack := strings.ToLower(entry.Kind + " " + entry.Content + " " + strings.Join(entry.Tags, " "))
		score := 0
		for _, term := range terms {
			count := strings.Count(haystack, term)
			if count > 0 {
				score += 3 + count
			}
		}
		if score > 0 {
			score += i * 2 / max(1, len(entries))
			scored = append(scored, scoredEntry{entry: entry, score: score})
		}
	}
	sort.SliceStable(scored, func(i, j int) bool {
		if scored[i].score == scored[j].score {
			return scored[i].entry.CreatedAt.After(scored[j].entry.CreatedAt)
		}
		return scored[i].score > scored[j].score
	})

	result := make([]MemoryEntry, 0, min(limit, len(scored)))
	for i := 0; i < len(scored) && i < limit; i++ {
		result = append(result, scored[i].entry)
	}
	return result, nil
}

func (s *MemoryStore) Projects() ([]string, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	items, err := os.ReadDir(filepath.Join(s.root, "projects"))
	if err != nil {
		return nil, fmt.Errorf("read projects: %w", err)
	}
	projects := make([]string, 0, len(items))
	for _, item := range items {
		if item.IsDir() && safeNamePattern.MatchString(item.Name()) {
			projects = append(projects, item.Name())
		}
	}
	sort.Strings(projects)
	return projects, nil
}

func (s *MemoryStore) readAll(projectID string) ([]MemoryEntry, error) {
	file, err := os.Open(filepath.Join(s.projectDir(projectID), "memory.jsonl"))
	if errors.Is(err, os.ErrNotExist) {
		return []MemoryEntry{}, nil
	}
	if err != nil {
		return nil, fmt.Errorf("open project memory: %w", err)
	}
	defer file.Close()

	entries := make([]MemoryEntry, 0)
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 64*1024), 2*maxMemoryContent)
	line := 0
	for scanner.Scan() {
		line++
		var entry MemoryEntry
		if err := json.Unmarshal(scanner.Bytes(), &entry); err != nil {
			return nil, fmt.Errorf("decode project memory line %d: %w", line, err)
		}
		entries = append(entries, entry)
	}
	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("scan project memory: %w", err)
	}
	return entries, nil
}

func (s *MemoryStore) projectDir(projectID string) string {
	return filepath.Join(s.root, "projects", projectID)
}

func validateProjectID(projectID string) error {
	if !safeNamePattern.MatchString(projectID) || projectID == "." || projectID == ".." {
		return fmt.Errorf("project_id must be 1-64 safe filename characters")
	}
	return nil
}

func validMemoryKind(kind string) bool {
	return kind == "context" || kind == "progress" || kind == "decision" || kind == "analysis"
}

func validateTags(tags []string) ([]string, error) {
	if len(tags) > maxMemoryTags {
		return nil, fmt.Errorf("at most %d tags are allowed", maxMemoryTags)
	}
	clean := make([]string, 0, len(tags))
	seen := make(map[string]struct{})
	for _, tag := range tags {
		tag = strings.ToLower(strings.TrimSpace(tag))
		if tag == "" {
			continue
		}
		if len(tag) > 32 || !safeNamePattern.MatchString(tag) {
			return nil, fmt.Errorf("tags must contain 1-32 safe filename characters")
		}
		if _, exists := seen[tag]; exists {
			continue
		}
		seen[tag] = struct{}{}
		clean = append(clean, tag)
	}
	return clean, nil
}

func tokenize(value string) []string {
	parts := strings.FieldsFunc(strings.ToLower(value), func(r rune) bool {
		return !unicode.IsLetter(r) && !unicode.IsDigit(r)
	})
	seen := make(map[string]struct{})
	terms := make([]string, 0, len(parts))
	for _, part := range parts {
		if len(part) < 2 {
			continue
		}
		if _, exists := seen[part]; exists {
			continue
		}
		seen[part] = struct{}{}
		terms = append(terms, part)
	}
	return terms
}

func reverseEntries(entries []MemoryEntry) {
	for left, right := 0, len(entries)-1; left < right; left, right = left+1, right-1 {
		entries[left], entries[right] = entries[right], entries[left]
	}
}

func newID(prefix string) (string, error) {
	random := make([]byte, 6)
	if _, err := rand.Read(random); err != nil {
		return "", fmt.Errorf("generate id: %w", err)
	}
	return fmt.Sprintf("%s_%d_%s", prefix, time.Now().UTC().UnixMilli(), hex.EncodeToString(random)), nil
}
