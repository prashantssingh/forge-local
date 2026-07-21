package main

import (
	"testing"
)

func TestMemoryStorePersistsAndRetrievesContinuity(t *testing.T) {
	root := t.TempDir()
	store, err := NewMemoryStore(root)
	if err != nil {
		t.Fatal(err)
	}
	first, err := store.Add("alpha", "decision", "Use a local API with durable memory.", []string{"architecture"})
	if err != nil {
		t.Fatal(err)
	}
	second, err := store.Add("alpha", "progress", "The health endpoint is complete.", []string{"api"})
	if err != nil {
		t.Fatal(err)
	}

	relevant, err := store.Search("alpha", "local memory architecture", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(relevant) != 1 || relevant[0].ID != first.ID {
		t.Fatalf("unexpected relevant memory: %#v", relevant)
	}
	recent, err := store.Search("alpha", "", 1)
	if err != nil {
		t.Fatal(err)
	}
	if len(recent) != 1 || recent[0].ID != second.ID {
		t.Fatalf("unexpected recent memory: %#v", recent)
	}

	reopened, err := NewMemoryStore(root)
	if err != nil {
		t.Fatal(err)
	}
	persisted, err := reopened.Search("alpha", "health", 5)
	if err != nil {
		t.Fatal(err)
	}
	if len(persisted) != 1 || persisted[0].ID != second.ID {
		t.Fatalf("memory did not persist: %#v", persisted)
	}
	projects, err := reopened.Projects()
	if err != nil {
		t.Fatal(err)
	}
	if len(projects) != 1 || projects[0] != "alpha" {
		t.Fatalf("unexpected projects: %#v", projects)
	}
}

func TestMemoryStoreRejectsUnsafeProjectID(t *testing.T) {
	store, err := NewMemoryStore(t.TempDir())
	if err != nil {
		t.Fatal(err)
	}
	if _, err := store.Add("../escape", "progress", "bad", nil); err == nil {
		t.Fatal("expected unsafe project id to fail")
	}
}
