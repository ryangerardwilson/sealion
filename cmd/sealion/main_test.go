package main

import (
	"bytes"
	"strings"
	"sync"
	"testing"
)

func TestProjectSlug(t *testing.T) {
	tests := map[string]string{
		"Demo":           "demo",
		"my_app.test":    "my-app-test",
		"  Weird Name  ": "weird-name",
		"already--clean": "already-clean",
		"___":            "",
	}

	for input, want := range tests {
		if got := projectSlug(input); got != want {
			t.Fatalf("projectSlug(%q) = %q, want %q", input, got, want)
		}
	}
}

func TestEnsureProjectName(t *testing.T) {
	valid := []string{"demo", "demo_app", "demo-app", "demo.app", "Demo1"}
	for _, name := range valid {
		if err := ensureProjectName(name); err != nil {
			t.Fatalf("ensureProjectName(%q) returned %v", name, err)
		}
	}

	invalid := []string{"", ".hidden", "two words", "nested/app", "bad*name"}
	for _, name := range invalid {
		if err := ensureProjectName(name); err == nil {
			t.Fatalf("ensureProjectName(%q) should fail", name)
		}
	}
}

func TestValidatePort(t *testing.T) {
	for _, value := range []string{"", "0", "65536", "abc"} {
		if _, err := validatePort(value); err == nil {
			t.Fatalf("validatePort(%q) should fail", value)
		}
	}

	got, err := validatePort("8080")
	if err != nil {
		t.Fatalf("validatePort returned %v", err)
	}
	if got != 8080 {
		t.Fatalf("validatePort returned %d, want 8080", got)
	}
}

func TestRendererPlainOutput(t *testing.T) {
	var out bytes.Buffer
	newRenderer(&out).Message(
		"Sealion",
		"project created",
		outputRow{"path", "/tmp/demo"},
		outputRow{"next", "cd demo"},
		outputRow{"", "sealion run dev"},
	)

	want := "Sealion\nproject created\n\npath  /tmp/demo\nnext  cd demo\n      sealion run dev\n"
	if out.String() != want {
		t.Fatalf("renderer output = %q, want %q", out.String(), want)
	}
}

func TestRendererIndentsMultilineValues(t *testing.T) {
	var out bytes.Buffer
	newRenderer(&out).Rows(outputRow{"error", "first line\nsecond line"})

	want := "error  first line\n       second line\n"
	if out.String() != want {
		t.Fatalf("renderer output = %q, want %q", out.String(), want)
	}
}

func TestStreamComposeOutputFiltersNoise(t *testing.T) {
	var out bytes.Buffer
	var wg sync.WaitGroup
	wg.Add(1)
	streamComposeOutput(strings.NewReader("Watch enabled\n\nrebuilt backend\n"), newRenderer(&out), &wg)
	wg.Wait()

	want := "compose  rebuilt backend\n"
	if out.String() != want {
		t.Fatalf("compose output = %q, want %q", out.String(), want)
	}
}
