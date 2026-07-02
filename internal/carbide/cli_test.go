package carbide

import (
	"bytes"
	"os"
	"path/filepath"
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

func TestBareCommandPrintsCommandList(t *testing.T) {
	var out bytes.Buffer
	a := app{stdout: &out}

	if err := a.run(nil); err != nil {
		t.Fatalf("run returned %v", err)
	}

	got := out.String()
	for _, want := range []string{
		"_____________________________________________________",
		"________________________oo_______oo_______oo_________",
		"Carbide 0.1.0-dev",
		"Usage:",
		"carbide <command> [arguments]",
		"Commands:",
		"new <project-name>",
		"init",
		"help",
	} {
		if !strings.Contains(got, want) {
			t.Fatalf("bare command output = %q, missing %q", got, want)
		}
	}
	for _, unwanted := range []string{
		"Options:",
		"Available commands:",
		"run dev",
		"status",
		"stop dev",
		"follow logs",
		"upgrade",
		"version",
		"features:",
		"raw.githubusercontent.com/ryangerardwilson/carbide",
	} {
		if strings.Contains(got, unwanted) {
			t.Fatalf("bare command output = %q, should not contain %q", got, unwanted)
		}
	}
}

func TestHelpPrintsRuntimeReference(t *testing.T) {
	var out bytes.Buffer
	a := app{stdout: &out}

	if err := a.run([]string{"help"}); err != nil {
		t.Fatalf("run returned %v", err)
	}

	got := out.String()
	if !strings.HasPrefix(got, "area") {
		t.Fatalf("help output = %q, should start with table header", got)
	}
	for _, line := range strings.Split(strings.TrimRight(got, "\n"), "\n") {
		if width := len(stripANSI(line)); width > 79 {
			t.Fatalf("help line is %d columns, want <= 79: %q", width, line)
		}
	}
	for _, want := range []string{
		"area",
		"command",
		"purpose",
		"start",
		"carbide new <project-name>",
		"carbide init",
		"develop",
		"carbide run dev",
		"carbide status",
		"carbide stop dev",
		"logs",
		"carbide follow logs",
		"carbide follow logs service backend",
		"carbide logs",
		"maintain",
		"carbide help",
		"carbide version",
		"carbide upgrade",
		"carbide logs containing \"/api/login\" json",
	} {
		if !strings.Contains(got, want) {
			t.Fatalf("help output = %q, missing %q", got, want)
		}
	}
	for _, unwanted := range []string{
		"Carbide\n",
		"Containerized full-stack apps with React, Go, and Postgres.",
		"_____________________________________________________",
		"________________________oo_______oo_______oo_________",
		"install the CLI",
		"<github-install-url>",
		"curl -fsSL",
		"raw.githubusercontent.com/ryangerardwilson/carbide",
		"features:",
		"global actions:",
	} {
		if strings.Contains(got, unwanted) {
			t.Fatalf("help output = %q, should not contain %q", got, unwanted)
		}
	}
}

func TestRendererStyledLogoUsesGlyphColors(t *testing.T) {
	r := renderer{styled: true}

	got := r.formatLogoLine(0, "_o0Ox")
	want := "\033[2;38;5;245m_\033[0m\033[38;5;220mo0O\033[0mx"
	if got != want {
		t.Fatalf("styled logo line = %q, want %q", got, want)
	}
	if plain := stripANSI(got); plain != "_o0Ox" {
		t.Fatalf("styled logo line strips to %q, want %q", plain, "_o0Ox")
	}
}

func TestRendererPlainOutput(t *testing.T) {
	var out bytes.Buffer
	newRenderer(&out).Message(
		"Carbide",
		"project created",
		outputRow{"path", "/tmp/demo"},
		outputRow{"next", "cd demo"},
		outputRow{"", "carbide run dev"},
	)

	want := "Carbide\nproject created\n\npath  /tmp/demo\nnext  cd demo\n      carbide run dev\n"
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

func TestRendererTable(t *testing.T) {
	var out bytes.Buffer
	newRenderer(&out).Table(
		[]string{"service", "container", "ports"},
		[]tableRow{
			{"frontend", "demo-frontend-1", "localhost:8082"},
			{"backend", "demo-backend-1", "-"},
		},
	)

	got := out.String()
	for _, want := range []string{
		"service   container        ports",
		"frontend  demo-frontend-1  localhost:8082",
		"backend   demo-backend-1   -",
	} {
		if !strings.Contains(got, want) {
			t.Fatalf("table output = %q, missing %q", got, want)
		}
	}
}

func TestServiceProgressFrame(t *testing.T) {
	tests := []struct {
		state string
		step  int
		want  string
	}{
		{"starting", 0, "[C o  o  o ]"},
		{"starting", 1, "[-c o  o  o]"},
		{"stopping", 0, "[ o  o  o D]"},
		{"stopping", 1, "[o  o  o d-]"},
		{"ready", 0, "[##########]"},
		{"stopped", 0, "[          ]"},
		{"failed", 0, "[!!!!!!!!!!]"},
	}
	for _, test := range tests {
		if got := serviceProgressFrame(10, test.step, test.state); got != test.want {
			t.Fatalf("serviceProgressFrame(10, %d, %q) = %q, want %q", test.step, test.state, got, test.want)
		}
	}
}

func TestRendererLogoPacmanLine(t *testing.T) {
	r := renderer{}
	tests := []struct {
		position int
		step     int
		want     string
	}{
		{-1, 0, " o  "},
		{1, 0, "_C o"},
		{1, 1, "_c o"},
		{4, 0, "_o0_"},
	}
	for _, test := range tests {
		got := r.formatLogoPacmanLine("_o0_", test.position, test.step)
		if got != test.want {
			t.Fatalf("formatLogoPacmanLine(position=%d, step=%d) = %q, want %q", test.position, test.step, got, test.want)
		}
	}
}

func TestRendererStyledLogoPacmanLine(t *testing.T) {
	r := renderer{styled: true}

	got := r.formatLogoPacmanLine("_o0_", 1, 0)
	for _, want := range []string{
		"\033[2;38;5;245m_\033[0m",
		"\033[1;38;5;226mC\033[0m",
		"\033[2;38;5;220mo\033[0m",
	} {
		if !strings.Contains(got, want) {
			t.Fatalf("styled pacman logo line = %q, missing %q", got, want)
		}
	}
	if plain := stripANSI(got); plain != "_C o" {
		t.Fatalf("styled pacman logo line strips to %q, want %q", plain, "_C o")
	}
}

func TestServiceProgressState(t *testing.T) {
	tests := []struct {
		status composeServiceStatus
		want   string
	}{
		{composeServiceStatus{state: "running"}, "ready"},
		{composeServiceStatus{state: "running", health: "healthy"}, "ready"},
		{composeServiceStatus{state: "running", health: "starting"}, "starting"},
		{composeServiceStatus{state: "exited"}, "failed"},
		{composeServiceStatus{}, "starting"},
	}
	for _, test := range tests {
		if got := serviceProgressState(test.status); got != test.want {
			t.Fatalf("serviceProgressState(%#v) = %q, want %q", test.status, got, test.want)
		}
	}
}

func TestServiceStopProgressState(t *testing.T) {
	tests := []struct {
		status composeServiceStatus
		want   string
	}{
		{composeServiceStatus{state: "running"}, "stopping"},
		{composeServiceStatus{state: "exited"}, "stopping"},
		{composeServiceStatus{state: "stopped"}, "stopped"},
		{composeServiceStatus{state: "failed"}, "failed"},
		{composeServiceStatus{}, "stopping"},
	}
	for _, test := range tests {
		if got := serviceStopProgressState(test.status); got != test.want {
			t.Fatalf("serviceStopProgressState(%#v) = %q, want %q", test.status, got, test.want)
		}
	}
}

func TestServiceProgressRunsWithoutColor(t *testing.T) {
	var out bytes.Buffer
	r := renderer{out: &out, interactive: true, termWidth: 52}

	err := r.RunServiceProgress(
		[]string{"backend"},
		func() map[string]composeServiceStatus {
			return nil
		},
		func() error {
			return nil
		},
	)
	if err != nil {
		t.Fatalf("RunServiceProgress returned %v", err)
	}

	got := out.String()
	lines := visibleTerminalLines(got)
	starting := terminalLineContaining(t, lines, "starting")
	ready := terminalLineContaining(t, lines, "ready")
	wantFrameWidth := 52 - len("backend") - progressStateColumnWidth - 5

	wantStarting := "backend  " + serviceProgressFrame(wantFrameWidth, 0, "starting") + " " + padRight("starting", progressStateColumnWidth)
	if starting != wantStarting {
		t.Fatalf("starting progress line = %q, want %q", starting, wantStarting)
	}
	if len(starting) != 52 {
		t.Fatalf("starting progress line width = %d, want 52: %q", len(starting), starting)
	}

	wantReady := "backend  " + serviceProgressFrame(wantFrameWidth, 0, "ready") + " " + padRight("ready", progressStateColumnWidth)
	if ready != wantReady {
		t.Fatalf("ready progress line = %q, want %q", ready, wantReady)
	}
	if len(ready) != 52 {
		t.Fatalf("ready progress line width = %d, want 52: %q", len(ready), ready)
	}
}

func TestServiceStopProgressRunsWithoutColor(t *testing.T) {
	var out bytes.Buffer
	r := renderer{out: &out, interactive: true, termWidth: 52}

	err := r.RunServiceStopProgress(
		[]string{"backend"},
		func() map[string]composeServiceStatus {
			return nil
		},
		func() error {
			return nil
		},
	)
	if err != nil {
		t.Fatalf("RunServiceStopProgress returned %v", err)
	}

	got := out.String()
	lines := visibleTerminalLines(got)
	stopping := terminalLineContaining(t, lines, "stopping")
	stopped := terminalLineContaining(t, lines, "stopped")
	wantFrameWidth := 52 - len("backend") - progressStateColumnWidth - 5

	wantStopping := "backend  " + serviceProgressFrame(wantFrameWidth, 0, "stopping") + " " + padRight("stopping", progressStateColumnWidth)
	if stopping != wantStopping {
		t.Fatalf("stopping progress line = %q, want %q", stopping, wantStopping)
	}
	if len(stopping) != 52 {
		t.Fatalf("stopping progress line width = %d, want 52: %q", len(stopping), stopping)
	}

	wantStopped := "backend  " + serviceProgressFrame(wantFrameWidth, 0, "stopped") + " " + padRight("stopped", progressStateColumnWidth)
	if stopped != wantStopped {
		t.Fatalf("stopped progress line = %q, want %q", stopped, wantStopped)
	}
	if len(stopped) != 52 {
		t.Fatalf("stopped progress line width = %d, want 52: %q", len(stopped), stopped)
	}
}

func TestServiceProgressFrameWidthUsesTerminalWidth(t *testing.T) {
	r := renderer{termWidth: 80}
	if got := r.serviceProgressFrameWidth(len("frontend")); got != 59 {
		t.Fatalf("serviceProgressFrameWidth = %d, want 59", got)
	}

	r = renderer{termWidth: 20}
	if got := r.serviceProgressFrameWidth(len("frontend")); got != minimumProgressFrameWidth {
		t.Fatalf("narrow serviceProgressFrameWidth = %d, want %d", got, minimumProgressFrameWidth)
	}
}

func visibleTerminalLines(output string) []string {
	plain := stripANSI(output)
	var lines []string
	for _, line := range strings.Split(plain, "\n") {
		if line == "" {
			continue
		}
		lines = append(lines, strings.TrimLeft(line, "\r"))
	}
	return lines
}

func terminalLineContaining(t *testing.T, lines []string, value string) string {
	t.Helper()
	for _, line := range lines {
		if strings.Contains(line, value) {
			return line
		}
	}
	t.Fatalf("terminal output missing %q in %#v", value, lines)
	return ""
}

func TestStreamWatchOutputFiltersNoise(t *testing.T) {
	var out bytes.Buffer
	var wg sync.WaitGroup
	wg.Add(1)
	streamWatchOutput(strings.NewReader("Watch enabled\n\nrebuilt backend\n"), newRenderer(&out), nil, "stdout", &wg)
	wg.Wait()

	got := out.String()
	if !strings.Contains(got, "watch      rebuilt backend\n") {
		t.Fatalf("watch output = %q", got)
	}
	if len(strings.Fields(got)[0]) != len("15:04:05") {
		t.Fatalf("watch output missing timestamp: %q", got)
	}
}

func TestStreamLogOutputParsesComposeServices(t *testing.T) {
	var out bytes.Buffer
	var wg sync.WaitGroup
	wg.Add(1)
	streamLogOutput(
		strings.NewReader("backend-1  | GET /health\nfrontend-1 | listening\ndemo-db-1 | ready\n"),
		newRenderer(&out),
		nil,
		"stdout",
		&wg,
	)
	wg.Wait()

	got := out.String()
	for _, want := range []string{
		"backend    GET /health",
		"frontend   listening",
		"db         ready",
	} {
		if !strings.Contains(got, want) {
			t.Fatalf("log output = %q, missing %q", got, want)
		}
	}
}

func TestStreamLogOutputWritesStructuredJSON(t *testing.T) {
	logPath := filepath.Join(t.TempDir(), "dev.jsonl")
	sink, err := openDevLogSink(logPath)
	if err != nil {
		t.Fatalf("openDevLogSink returned %v", err)
	}

	var out bytes.Buffer
	var wg sync.WaitGroup
	wg.Add(1)
	streamLogOutput(strings.NewReader("backend-1 | GET /health\n"), newRenderer(&out), sink, "stdout", &wg)
	wg.Wait()
	if err := sink.Close(); err != nil {
		t.Fatalf("Close returned %v", err)
	}

	data, err := os.ReadFile(logPath)
	if err != nil {
		t.Fatalf("ReadFile returned %v", err)
	}
	text := string(data)
	for _, want := range []string{
		`"source":"compose-log"`,
		`"stream":"stdout"`,
		`"service":"backend"`,
		`"message":"GET /health"`,
	} {
		if !strings.Contains(text, want) {
			t.Fatalf("structured log %q missing %s", text, want)
		}
	}
}

func TestParseLogQuery(t *testing.T) {
	query, err := parseLogQuery([]string{"service", "backend", "containing", "health", "limit", "5", "json"})
	if err != nil {
		t.Fatalf("parseLogQuery returned %v", err)
	}
	if query.service != "backend" || query.contains != "health" || query.limit != 5 || !query.json {
		t.Fatalf("query = %#v", query)
	}

	if _, err = parseLogQuery([]string{"follow", "service", "frontend"}); err == nil {
		t.Fatalf("parseLogQuery should reject follow as a logs option")
	}
}

func TestParseComposeServiceStatuses(t *testing.T) {
	statuses, err := parseComposeServiceStatuses(`[
{"Service":"frontend","Name":"demo-frontend-1","State":"running","Health":"","Publishers":[{"URL":"0.0.0.0","TargetPort":8080,"PublishedPort":8082,"Protocol":"tcp"},{"URL":"::","TargetPort":8080,"PublishedPort":8082,"Protocol":"tcp"}]},
{"Service":"backend","Name":"demo-backend-1","State":"running","Health":"healthy","Publishers":[{"URL":"","TargetPort":8080,"PublishedPort":0,"Protocol":"tcp"}]},
{"Service":"db","Name":"demo-db-1","State":"created","Health":"starting","Publishers":[{"URL":"","TargetPort":5432,"PublishedPort":0,"Protocol":"tcp"}]}
]`)
	if err != nil {
		t.Fatalf("parseComposeServiceStatuses returned %v", err)
	}
	if serviceProgressState(statuses["frontend"]) != "ready" {
		t.Fatalf("frontend status = %#v", statuses["frontend"])
	}
	if serviceProgressState(statuses["backend"]) != "ready" {
		t.Fatalf("backend status = %#v", statuses["backend"])
	}
	if serviceProgressState(statuses["db"]) != "starting" {
		t.Fatalf("db status = %#v", statuses["db"])
	}

	snapshots, err := parseComposeServiceSnapshots(`[
{"Service":"frontend","Name":"demo-frontend-1","State":"running","Health":"","Publishers":[{"URL":"0.0.0.0","TargetPort":8080,"PublishedPort":8082,"Protocol":"tcp"},{"URL":"::","TargetPort":8080,"PublishedPort":8082,"Protocol":"tcp"}]},
{"Service":"backend","Name":"demo-backend-1","State":"running","Health":"healthy","Publishers":[{"URL":"","TargetPort":8080,"PublishedPort":0,"Protocol":"tcp"}]}
]`)
	if err != nil {
		t.Fatalf("parseComposeServiceSnapshots returned %v", err)
	}
	if got := composePublishedPorts(snapshots["frontend"]); got != "localhost:8082" {
		t.Fatalf("frontend published ports = %q", got)
	}
	if got := composeInternalPorts(snapshots["backend"]); got != "8080/tcp" {
		t.Fatalf("backend internal ports = %q", got)
	}
	if got := composeServiceStatusText(snapshots["backend"]); got != "running (healthy)" {
		t.Fatalf("backend status text = %q", got)
	}

	statuses, err = parseComposeServiceStatuses(`{"Service":"backend","State":"exited","Health":""}`)
	if err != nil {
		t.Fatalf("parseComposeServiceStatuses line mode returned %v", err)
	}
	if serviceProgressState(statuses["backend"]) != "failed" {
		t.Fatalf("backend status = %#v", statuses["backend"])
	}
}

func TestFilterAndLimitLogEntries(t *testing.T) {
	entries := []structuredLogEntry{
		{Service: "frontend", Message: "listening"},
		{Service: "backend", Message: "GET /health"},
		{Service: "backend", Message: "POST /api/login"},
	}

	filtered := filterLogEntries(entries, logQuery{service: "backend", contains: "api"})
	if len(filtered) != 1 || filtered[0].Message != "POST /api/login" {
		t.Fatalf("filtered = %#v", filtered)
	}

	limited := limitLogEntries(entries, 2)
	if len(limited) != 2 || limited[0].Message != "GET /health" {
		t.Fatalf("limited = %#v", limited)
	}
}
