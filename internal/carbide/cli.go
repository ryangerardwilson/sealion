package carbide

import (
	"bufio"
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"net"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
	"unsafe"
)

var version = "0.1.0-dev"
var commit = ""

const devLogPath = ".carbide/log/dev.jsonl"
const defaultTerminalWidth = 80
const progressStateColumnWidth = 8
const minimumProgressFrameWidth = 4

const defaultLogoText = `_____________________________________________________
________________________oo_______oo_______oo_________
_ooooo___ooooo__oo_ooo__oooooo________oooooo__ooooo__
oo___oo_oo___oo_ooo___o_oo___oo__oo__oo___oo_oo____o_
oo______oo___oo_oo______oo___oo__oo__oo___oo_ooooooo_
oo______oo___oo_oo______oo___oo__oo__oo___oo_oo______
_ooooo___oooo_o_oo______oooooo__oooo__oooooo__ooooo__
_____________________________________________________
`

const commandListText = `Carbide %s

Usage:
  carbide <command> [arguments]

Commands:
  new <project-name>   Create a new Carbide project
  init                 Initialize the current empty directory
  help                 Show detailed help
`

type app struct {
	home   string
	stdout io.Writer
	stderr io.Writer
}

type composeCommand struct {
	name    string
	base    []string
	help    string
	logHelp string
}

type renderer struct {
	out         io.Writer
	styled      bool
	interactive bool
	termWidth   int
}

type outputRow struct {
	key   string
	value string
}

type tableRow []string

type runningProcess struct {
	name string
	cmd  *exec.Cmd
}

type processResult struct {
	name string
	err  error
}

type structuredLogEntry struct {
	Time    string `json:"ts"`
	Source  string `json:"source"`
	Stream  string `json:"stream"`
	Service string `json:"service"`
	Message string `json:"message"`
}

type devLogSink struct {
	mu      sync.Mutex
	file    *os.File
	encoder *json.Encoder
}

type logQuery struct {
	service  string
	contains string
	limit    int
	json     bool
}

type composeServiceStatus struct {
	service string
	state   string
	health  string
}

type composeServicePort struct {
	URL           string `json:"URL"`
	TargetPort    int    `json:"TargetPort"`
	PublishedPort int    `json:"PublishedPort"`
	Protocol      string `json:"Protocol"`
}

type composeServiceSnapshot struct {
	Service    string               `json:"Service"`
	Name       string               `json:"Name"`
	State      string               `json:"State"`
	Health     string               `json:"Health"`
	Status     string               `json:"Status"`
	Ports      string               `json:"Ports"`
	Publishers []composeServicePort `json:"Publishers"`
}

func SetCommit(value string) {
	if value != "" {
		commit = value
	}
}

func Main() {
	home, err := resolveHome()
	if err != nil {
		renderError(os.Stderr, err)
		os.Exit(1)
	}

	a := app{
		home:   home,
		stdout: os.Stdout,
		stderr: os.Stderr,
	}

	if err := a.run(os.Args[1:]); err != nil {
		renderError(os.Stderr, err)
		os.Exit(1)
	}
}

func (a app) run(args []string) error {
	if len(args) == 0 {
		a.printCommandList()
		return nil
	}

	switch args[0] {
	case "help", "-h", "--help":
		if len(args) != 1 {
			return errors.New("usage: carbide help")
		}
		a.printHelp()
		return nil
	case "version":
		if len(args) != 1 {
			return errors.New("usage: carbide version")
		}
		return a.commandVersion()
	case "upgrade":
		if len(args) != 1 {
			return errors.New("usage: carbide upgrade")
		}
		return a.commandUpgrade()
	case "new":
		if len(args) != 2 {
			return errors.New("usage: carbide new <project-name>")
		}
		return a.commandNew(args[1])
	case "init":
		if len(args) != 1 {
			return errors.New("usage: carbide init")
		}
		return a.commandInit()
	case "run":
		if len(args) == 2 && args[1] == "dev" {
			return a.commandRunDev()
		}
		return errors.New("usage: carbide run dev")
	case "status":
		if len(args) == 1 {
			return a.commandStatus()
		}
		return errors.New("usage: carbide status")
	case "stop":
		if len(args) == 2 && args[1] == "dev" {
			return a.commandStopDev()
		}
		return errors.New("usage: carbide stop dev")
	case "follow":
		if len(args) >= 2 && args[1] == "logs" {
			return a.commandFollowLogs(args[2:])
		}
		return errors.New("usage: carbide follow logs [service <name>] [containing <text>]")
	case "logs":
		return a.commandLogs(args[1:])
	default:
		return fmt.Errorf("unknown command: %s", args[0])
	}
}

func (a app) printCommandList() {
	r := newRenderer(a.stdout)
	logo := carbideLogo(a.home)
	if r.interactive {
		r.AnimateLogo(logo)
	} else {
		r.Logo(logo)
	}
	text := fmt.Sprintf(commandListText, version)
	if r.styled {
		fmt.Fprint(a.stdout, r.paint("38;5;245", text))
		return
	}
	fmt.Fprint(a.stdout, text)
}

func (a app) printHelp() {
	r := newRenderer(a.stdout)
	r.Table(
		[]string{"area", "command", "purpose"},
		[]tableRow{
			{"start", "carbide new <project-name>", "create project directory"},
			{"", "carbide init", "init current directory"},
			{"develop", "carbide run dev", "start Docker dev stack"},
			{"", "carbide status", "show containers and ports"},
			{"", "carbide stop dev", "stop dev containers"},
			{"logs", "carbide follow logs", "stream live logs"},
			{"", "carbide follow logs service backend", "stream one service"},
			{"", "carbide logs", "query saved logs"},
			{"", "carbide logs containing \"/api/login\" json", "query logs as JSON"},
			{"maintain", "carbide help", "show this table"},
			{"", "carbide version", "print installed version"},
			{"", "carbide upgrade", "upgrade CLI from GitHub"},
		},
	)
}

func (a app) commandVersion() error {
	r := newRenderer(a.stdout)
	if commit != "" {
		r.Title("Carbide", "installed CLI")
		r.Rows(
			outputRow{"version", version},
			outputRow{"commit", commit},
		)
		return nil
	} else if head := gitShortHead(a.home); head != "" {
		r.Title("Carbide", "installed CLI")
		r.Rows(
			outputRow{"version", version},
			outputRow{"commit", head},
		)
		return nil
	}
	r.Title("Carbide", "installed CLI")
	r.Rows(outputRow{"version", version})
	return nil
}

func (a app) commandNew(name string) error {
	if err := ensureProjectName(name); err != nil {
		return err
	}

	target, err := filepath.Abs(filepath.Join(".", name))
	if err != nil {
		return err
	}
	if _, err := os.Stat(target); err == nil {
		return fmt.Errorf("%s already exists", name)
	} else if !errors.Is(err, os.ErrNotExist) {
		return err
	}

	slug := projectSlug(name)
	if slug == "" {
		slug = "carbide-app"
	}
	if err := a.copyTemplate(target, name, slug); err != nil {
		return err
	}

	newRenderer(a.stdout).Message(
		"Carbide",
		"project created",
		outputRow{"path", target},
		outputRow{"next", fmt.Sprintf("cd %s", name)},
		outputRow{"", "carbide run dev"},
	)
	return nil
}

func (a app) commandInit() error {
	empty, err := isCurrentDirEmpty()
	if err != nil {
		return err
	}
	if !empty {
		return errors.New("carbide init requires an empty directory")
	}

	pwd, err := os.Getwd()
	if err != nil {
		return err
	}
	name := filepath.Base(pwd)
	if err := ensureProjectName(name); err != nil {
		return err
	}

	slug := projectSlug(name)
	if slug == "" {
		slug = "carbide-app"
	}
	if err := a.copyTemplate(pwd, name, slug); err != nil {
		return err
	}

	newRenderer(a.stdout).Message(
		"Carbide",
		"project initialized",
		outputRow{"path", pwd},
		outputRow{"next", "carbide run dev"},
	)
	return nil
}

func (a app) commandUpgrade() error {
	if isDir(filepath.Join(a.home, ".git")) {
		if _, err := exec.LookPath("git"); err != nil {
			return errors.New("git is required to upgrade this installation")
		}

		status, err := commandOutput(a.home, "git", "status", "--porcelain")
		if err != nil {
			return err
		}
		if strings.TrimSpace(status) != "" {
			return fmt.Errorf("cannot upgrade because %s has local changes", a.home)
		}

		currentHead, err := commandOutput(a.home, "git", "rev-parse", "--short", "HEAD")
		if err != nil {
			return err
		}
		if _, err := commandOutput(a.home, "git", "fetch", "--quiet", "origin", "main"); err != nil {
			return err
		}
		remoteHead, err := commandOutput(a.home, "git", "rev-parse", "--short", "origin/main")
		if err != nil {
			return err
		}
		if currentHead == remoteHead {
			newRenderer(a.stdout).Message(
				"Carbide upgrade",
				"installed CLI",
				outputRow{"status", "up to date"},
				outputRow{"commit", currentHead},
			)
			return nil
		}
		if _, err := commandOutput(a.home, "git", "pull", "--ff-only", "--quiet", "origin", "main"); err != nil {
			return err
		}
		newHead, err := commandOutput(a.home, "git", "rev-parse", "--short", "HEAD")
		if err != nil {
			return err
		}
		if err := buildInstalledBinary(a.home); err != nil {
			return err
		}
		newRenderer(a.stdout).Message(
			"Carbide upgrade",
			"installed CLI",
			outputRow{"status", "upgraded"},
			outputRow{"from", currentHead},
			outputRow{"to", newHead},
		)
		return nil
	}

	installScript := filepath.Join(a.home, "install.sh")
	if !isFile(installScript) {
		return errors.New("cannot find install.sh for this Carbide installation")
	}
	cmd := exec.Command("bash", installScript)
	cmd.Env = append(os.Environ(), "CARBIDE_HOME="+a.home)
	cmd.Stdin = os.Stdin
	cmd.Stdout = a.stdout
	cmd.Stderr = a.stderr
	return cmd.Run()
}

func (a app) commandRunDev() error {
	if !isFile("carbide.toml") {
		return errors.New("run this inside a Carbide project")
	}

	compose, err := findCompose()
	if err != nil {
		return err
	}

	requestedPort := os.Getenv("CARBIDE_HTTP_PORT")
	port, err := chooseDevPort(requestedPort)
	if err != nil {
		return err
	}

	env := setEnv(os.Environ(), "CARBIDE_HTTP_PORT", strconv.Itoa(port))
	env = setEnv(env, "COMPOSE_MENU", "false")
	watch := compose.supports("--watch")
	logSink, err := openDevLogSink(devLogPath)
	if err != nil {
		return err
	}
	defer logSink.Close()

	r := newRenderer(a.stdout)
	a.printDevHeader(r, port)
	logSink.Write("carbide", "lifecycle", "cli", "starting containers")
	services := composeServices(compose, env)
	if err := r.RunServiceProgress(
		services,
		func() map[string]composeServiceStatus {
			return composeServiceStatuses(compose, env)
		},
		func() error {
			return composeUpDetached(compose, env)
		},
	); err != nil {
		logSink.Write("carbide", "lifecycle", "cli", err.Error())
		return err
	}
	logSink.Write("carbide", "lifecycle", "cli", "ready")
	r.Section("Logs", "live container output")

	return a.runDevStreams(compose, env, watch, logSink)
}

func (a app) commandStopDev() error {
	if !isFile("carbide.toml") {
		return errors.New("run this inside a Carbide project")
	}

	compose, err := findCompose()
	if err != nil {
		return err
	}

	env := setEnv(os.Environ(), "COMPOSE_MENU", "false")
	services := composeServices(compose, env)
	r := newRenderer(a.stdout)
	r.Title("Carbide stop dev", "local stack")

	logSink, _ := openAppendDevLogSink(devLogPath)
	if logSink != nil {
		defer logSink.Close()
		logSink.Write("carbide", "lifecycle", "cli", "stopping containers")
	}

	if err := r.RunServiceStopProgress(
		services,
		func() map[string]composeServiceStatus {
			return composeServiceStatuses(compose, env)
		},
		func() error {
			return composeDown(compose, env)
		},
	); err != nil {
		if logSink != nil {
			logSink.Write("carbide", "lifecycle", "cli", err.Error())
		}
		return err
	}
	if logSink != nil {
		logSink.Write("carbide", "lifecycle", "cli", "stopped containers")
	}
	r.Rows(outputRow{"dev", "stopped"})
	return nil
}

func (a app) commandStatus() error {
	if !isFile("carbide.toml") {
		return errors.New("run this inside a Carbide project")
	}

	compose, err := findCompose()
	if err != nil {
		return err
	}

	env := setEnv(os.Environ(), "COMPOSE_MENU", "false")
	services := composeServices(compose, env)
	snapshots, err := composeServiceSnapshots(compose, env)
	if err != nil {
		return err
	}

	seen := map[string]bool{}
	rows := make([]tableRow, 0, len(services))
	for _, service := range services {
		snapshot, ok := snapshots[service]
		if !ok {
			rows = append(rows, tableRow{service, "-", "-", "-", "not running"})
			continue
		}
		seen[service] = true
		rows = append(rows, composeStatusRow(snapshot))
	}
	for service, snapshot := range snapshots {
		if !seen[service] {
			rows = append(rows, composeStatusRow(snapshot))
		}
	}

	r := newRenderer(a.stdout)
	r.Title("Carbide status", "local stack")
	r.Table(
		[]string{"service", "container", "ports", "internal", "status"},
		rows,
	)
	return nil
}

func (a app) printDevHeader(r renderer, port int) {
	r.Title("Carbide dev", "local stack")
	r.Rows(
		outputRow{"app", fmt.Sprintf("http://localhost:%d", port)},
		outputRow{"api", fmt.Sprintf("http://localhost:%d/api", port)},
	)
}

func (a app) runDevStreams(compose composeCommand, env []string, watch bool, logSink *devLogSink) error {
	var streams sync.WaitGroup
	results := make(chan processResult, 3)
	processes := make([]runningProcess, 0, 2)

	logProcess, err := a.startComposeStream(
		"logs",
		compose,
		env,
		composeLogsArgs(compose),
		func(input io.Reader, r renderer, sink *devLogSink, stream string, wg *sync.WaitGroup) {
			streamLogOutput(input, r, sink, stream, wg)
		},
		logSink,
		&streams,
		results,
	)
	if err != nil {
		return err
	}
	processes = append(processes, logProcess)

	if watch {
		watchProcess, err := a.startComposeStream(
			"watch",
			compose,
			env,
			[]string{"watch", "--no-up", "--quiet"},
			func(input io.Reader, r renderer, sink *devLogSink, stream string, wg *sync.WaitGroup) {
				streamWatchOutput(input, r, sink, stream, wg)
			},
			logSink,
			&streams,
			results,
		)
		if err != nil {
			stopProcesses(processes, syscall.SIGTERM)
			waitForProcesses(len(processes), processes, results, 5*time.Second)
			streams.Wait()
			return err
		}
		processes = append(processes, watchProcess)
	}

	signals := make(chan os.Signal, 1)
	signal.Notify(signals, os.Interrupt, syscall.SIGTERM)
	defer signal.Stop(signals)

	var first processResult
	interrupted := false

	select {
	case sig := <-signals:
		interrupted = true
		logSink.Write("carbide", "lifecycle", "cli", "detached from dev logs")
		stopProcesses(processes, sig)
	case first = <-results:
		stopProcesses(processes, syscall.SIGTERM)
	}

	alreadyReported := 0
	if !interrupted {
		alreadyReported = 1
	}
	waitForProcesses(len(processes)-alreadyReported, processes, results, 5*time.Second)
	streams.Wait()

	if interrupted {
		r := newRenderer(a.stdout)
		r.Blank()
		r.Rows(
			outputRow{"logs", "detached"},
			outputRow{"dev", "running"},
			outputRow{"follow", "carbide follow logs"},
			outputRow{"stop", "carbide stop dev"},
		)
		return nil
	}
	if first.err != nil {
		return fmt.Errorf("Docker Compose %s failed: %w", first.name, first.err)
	}
	return nil
}

func (a app) startComposeStream(
	name string,
	compose composeCommand,
	env []string,
	args []string,
	stream func(io.Reader, renderer, *devLogSink, string, *sync.WaitGroup),
	logSink *devLogSink,
	streams *sync.WaitGroup,
	results chan<- processResult,
) (runningProcess, error) {
	cmd := exec.Command(compose.name, compose.args(args...)...)
	cmd.Env = env
	cmd.Stdin = os.Stdin

	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return runningProcess{}, err
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return runningProcess{}, err
	}

	if err := cmd.Start(); err != nil {
		return runningProcess{}, fmt.Errorf("Docker Compose %s failed to start: %w", name, err)
	}

	streams.Add(2)
	go stream(stdout, newRenderer(a.stdout), logSink, "stdout", streams)
	go stream(stderr, newRenderer(a.stderr), logSink, "stderr", streams)

	go func() {
		results <- processResult{name: name, err: cmd.Wait()}
	}()

	return runningProcess{name: name, cmd: cmd}, nil
}

func stopProcesses(processes []runningProcess, sig os.Signal) {
	for _, process := range processes {
		if process.cmd.Process != nil {
			_ = process.cmd.Process.Signal(sig)
		}
	}
}

func waitForProcesses(remaining int, processes []runningProcess, results <-chan processResult, timeout time.Duration) {
	deadline := time.After(timeout)
	for remaining > 0 {
		select {
		case <-results:
			remaining--
		case <-deadline:
			for _, process := range processes {
				if process.cmd.Process != nil {
					_ = process.cmd.Process.Kill()
				}
			}
			for remaining > 0 {
				<-results
				remaining--
			}
		}
	}
}

func newRenderer(out io.Writer) renderer {
	interactive := isTerminalOutput(out)
	termWidth := 0
	if interactive {
		termWidth = terminalColumns(out)
		if termWidth == 0 {
			termWidth = terminalColumnsFromEnv()
		}
	}
	return renderer{
		out:         out,
		interactive: interactive,
		styled:      interactive && os.Getenv("NO_COLOR") == "",
		termWidth:   termWidth,
	}
}

func renderError(out io.Writer, err error) {
	newRenderer(out).Message(
		"Carbide",
		"command failed",
		outputRow{"error", err.Error()},
		outputRow{"help", "carbide help"},
	)
}

func (r renderer) Message(title string, subtitle string, rows ...outputRow) {
	r.Title(title, subtitle)
	r.Rows(rows...)
}

func (r renderer) Title(title string, subtitle string) {
	if r.styled {
		fmt.Fprintf(r.out, "%s\n", r.paint("1;38;5;81", title))
		if subtitle != "" {
			fmt.Fprintf(r.out, "%s\n", r.paint("2;38;5;245", subtitle))
		}
	} else {
		fmt.Fprintln(r.out, title)
		if subtitle != "" {
			fmt.Fprintln(r.out, subtitle)
		}
	}
	fmt.Fprintln(r.out)
}

func (r renderer) Section(title string, subtitle string) {
	fmt.Fprintln(r.out)
	if r.styled {
		fmt.Fprintf(r.out, "%s\n", r.paint("1;38;5;245", title))
		if subtitle != "" {
			fmt.Fprintf(r.out, "%s\n", r.paint("2;38;5;245", subtitle))
		}
	} else {
		fmt.Fprintln(r.out, title)
		if subtitle != "" {
			fmt.Fprintln(r.out, subtitle)
		}
	}
	fmt.Fprintln(r.out)
}

func (r renderer) Rows(rows ...outputRow) {
	width := rowKeyWidth(rows)
	for _, row := range rows {
		r.writeRow(row, width)
	}
}

func (r renderer) Table(headers []string, rows []tableRow) {
	widths := make([]int, len(headers))
	for index, header := range headers {
		widths[index] = len(header)
	}
	for _, row := range rows {
		for index := range headers {
			value := ""
			if index < len(row) {
				value = row[index]
			}
			if len(value) > widths[index] {
				widths[index] = len(value)
			}
		}
	}

	writeCells := func(cells []string, header bool) {
		for index := range headers {
			value := ""
			if index < len(cells) {
				value = cells[index]
			}
			if index > 0 {
				fmt.Fprint(r.out, "  ")
			}
			padded := value
			if index < len(headers)-1 {
				padded += strings.Repeat(" ", widths[index]-len(value))
			}
			if header {
				padded = r.paint("2;38;5;245", padded)
			}
			fmt.Fprint(r.out, padded)
		}
		fmt.Fprintln(r.out)
	}

	writeCells(headers, true)
	for _, row := range rows {
		writeCells([]string(row), false)
	}
}

func (r renderer) Row(row outputRow) {
	r.writeRow(row, len(row.key))
}

func (r renderer) Blank() {
	fmt.Fprintln(r.out)
}

func (r renderer) Logo(logo string) {
	for index, line := range logoLines(logo) {
		fmt.Fprintln(r.out, r.formatLogoLine(index, line))
	}
	fmt.Fprintln(r.out)
}

func (r renderer) AnimateLogo(logo string) {
	lines := logoLines(logo)
	if len(lines) == 0 {
		return
	}

	width := maxLineWidth(lines)
	chompFrames := width + (len(lines)-1)*2 + 1
	for frame := 0; frame <= chompFrames; frame++ {
		if frame > 0 {
			fmt.Fprintf(r.out, "\033[%dA", len(lines))
		}
		for index, line := range lines {
			position := frame - index*2
			fmt.Fprintf(r.out, "\r\033[K%s\n", r.formatLogoPacmanLine(line, position, frame+index))
		}
		if frame < chompFrames {
			time.Sleep(9 * time.Millisecond)
		}
	}
	fmt.Fprintln(r.out)
}

func (r renderer) writeRow(row outputRow, width int) {
	lines := strings.Split(row.value, "\n")
	if len(lines) > 1 {
		r.writeSingleLine(outputRow{row.key, lines[0]}, width)
		for _, line := range lines[1:] {
			r.writeSingleLine(outputRow{"", line}, width)
		}
		return
	}
	r.writeSingleLine(row, width)
}

func (r renderer) writeSingleLine(row outputRow, width int) {
	if row.key == "" {
		fmt.Fprintf(r.out, "%*s  %s\n", width, "", r.formatValue(row))
		return
	}
	key := r.formatKey(row.key)
	if r.styled {
		fmt.Fprintf(r.out, "%s%s  %s\n", key, strings.Repeat(" ", width-len(row.key)), r.formatValue(row))
		return
	}
	fmt.Fprintf(r.out, "%-*s  %s\n", width, row.key, row.value)
}

func (r renderer) Log(service string, message string) {
	r.LogAt(time.Now(), service, message)
}

func (r renderer) LogEntry(entry structuredLogEntry) {
	r.LogAt(entryTimestamp(entry), entry.Service, entry.Message)
}

func (r renderer) LogAt(timestamp time.Time, service string, message string) {
	label := service
	if label == "" {
		label = "log"
	}
	if timestamp.IsZero() {
		timestamp = time.Now()
	}
	stamp := timestamp.Local().Format("15:04:05")
	width := 9
	if len(label) > width {
		width = len(label)
	}
	if r.styled {
		fmt.Fprintf(
			r.out,
			"%s  %s%s  %s\n",
			r.paint("2;38;5;245", stamp),
			r.formatService(label),
			strings.Repeat(" ", width-len(label)),
			message,
		)
		return
	}
	fmt.Fprintf(r.out, "%s  %-*s  %s\n", stamp, width, label, message)
}

func (r renderer) RunServiceProgress(
	services []string,
	poll func() map[string]composeServiceStatus,
	work func() error,
) error {
	return r.runServiceProgress("start", services, poll, work)
}

func (r renderer) RunServiceStopProgress(
	services []string,
	poll func() map[string]composeServiceStatus,
	work func() error,
) error {
	return r.runServiceProgress("stop", services, poll, work)
}

func (r renderer) runServiceProgress(
	mode string,
	services []string,
	poll func() map[string]composeServiceStatus,
	work func() error,
) error {
	if !r.interactive {
		return work()
	}

	done := make(chan error, 1)
	go func() {
		done <- work()
	}()

	if len(services) == 0 {
		services = []string{"containers"}
	}
	statuses := map[string]composeServiceStatus{}
	step := 0
	r.writeServiceProgress(mode, services, statuses, step)
	ticker := time.NewTicker(140 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case err := <-done:
			if err != nil {
				for _, service := range services {
					statuses[service] = composeServiceStatus{service: service, state: "failed"}
				}
				r.rewriteServiceProgress(mode, services, statuses, step)
				return err
			}
			for _, service := range services {
				statuses[service] = composeServiceStatus{service: service, state: progressDoneState(mode), health: "healthy"}
			}
			r.rewriteServiceProgress(mode, services, statuses, step)
			return nil
		case <-ticker.C:
			step++
			if current := poll(); len(current) > 0 {
				statuses = current
			}
			r.rewriteServiceProgress(mode, services, statuses, step)
		}
	}
}

func (r renderer) rewriteServiceProgress(mode string, services []string, statuses map[string]composeServiceStatus, step int) {
	fmt.Fprintf(r.out, "\033[%dA", len(services))
	r.writeServiceProgress(mode, services, statuses, step)
}

func (r renderer) writeServiceProgress(mode string, services []string, statuses map[string]composeServiceStatus, step int) {
	width := rowTextWidth(services)
	frameWidth := r.serviceProgressFrameWidth(width)
	for index, service := range services {
		status := statuses[service]
		state := progressState(mode, status)
		frame := serviceProgressFrame(frameWidth, step+index, state)
		stateLabel := padRight(state, progressStateColumnWidth)
		fmt.Fprintf(
			r.out,
			"\r\033[K%s%s  %s %s\n",
			r.formatService(service),
			strings.Repeat(" ", width-len(service)),
			r.paint(serviceProgressColor(state), frame),
			r.paint("2;38;5;245", stateLabel),
		)
	}
}

func (r renderer) serviceProgressFrameWidth(serviceWidth int) int {
	termWidth := r.currentTerminalWidth()
	frameWidth := termWidth - serviceWidth - progressStateColumnWidth - 5
	if frameWidth < minimumProgressFrameWidth {
		return minimumProgressFrameWidth
	}
	return frameWidth
}

func (r renderer) currentTerminalWidth() int {
	if r.interactive {
		if width := terminalColumns(r.out); width > 0 {
			return width
		}
	}
	if r.termWidth > 0 {
		return r.termWidth
	}
	return defaultTerminalWidth
}

func progressDoneState(mode string) string {
	if mode == "stop" {
		return "stopped"
	}
	return "running"
}

func progressState(mode string, status composeServiceStatus) string {
	if mode == "stop" {
		return serviceStopProgressState(status)
	}
	return serviceProgressState(status)
}

func serviceProgressFrame(width int, step int, state string) string {
	if width < 1 {
		width = 1
	}
	switch state {
	case "ready":
		return "[" + strings.Repeat("#", width) + "]"
	case "stopped":
		return "[" + strings.Repeat(" ", width) + "]"
	case "failed":
		return "[" + strings.Repeat("!", width) + "]"
	case "stopping":
		return reversePacmanFrame(width, step)
	default:
		return pacmanFrame(width, step)
	}
}

func pacmanFrame(width int, step int) string {
	position := step % width
	if position < 0 {
		position = 0
	}
	var b strings.Builder
	b.WriteByte('[')
	for i := 0; i < width; i++ {
		switch {
		case i == position:
			b.WriteByte(pacmanMouth(step, "right"))
		case i < position:
			b.WriteByte('-')
		case isCandyPosition(i - position):
			b.WriteByte('o')
		default:
			b.WriteByte(' ')
		}
	}
	b.WriteByte(']')
	return b.String()
}

func reversePacmanFrame(width int, step int) string {
	position := width - 1 - (step % width)
	if position < 0 {
		position = 0
	}
	var b strings.Builder
	b.WriteByte('[')
	for i := 0; i < width; i++ {
		switch {
		case i == position:
			b.WriteByte(pacmanMouth(step, "left"))
		case i > position:
			b.WriteByte('-')
		case isCandyPosition(position - i):
			b.WriteByte('o')
		default:
			b.WriteByte(' ')
		}
	}
	b.WriteByte(']')
	return b.String()
}

func isCandyPosition(distance int) bool {
	return distance > 1 && (distance-2)%3 == 0
}

func pacmanMouth(step int, direction string) byte {
	open := step%2 == 0
	if direction == "left" {
		if open {
			return 'D'
		}
		return 'd'
	}
	if open {
		return 'C'
	}
	return 'c'
}

func serviceProgressState(status composeServiceStatus) string {
	state := strings.ToLower(status.state)
	health := strings.ToLower(status.health)
	if state == "failed" || state == "exited" || state == "dead" {
		return "failed"
	}
	if state == "running" && (health == "" || health == "healthy") {
		return "ready"
	}
	if health == "healthy" {
		return "ready"
	}
	return "starting"
}

func serviceStopProgressState(status composeServiceStatus) string {
	state := strings.ToLower(status.state)
	if state == "failed" || state == "dead" {
		return "failed"
	}
	if state == "stopped" {
		return "stopped"
	}
	return "stopping"
}

func serviceProgressColor(state string) string {
	switch state {
	case "ready":
		return "38;5;114"
	case "stopped":
		return "2;38;5;245"
	case "failed":
		return "38;5;203"
	default:
		return "38;5;81"
	}
}

func rowTextWidth(values []string) int {
	width := 0
	for _, value := range values {
		if len(value) > width {
			width = len(value)
		}
	}
	return width
}

func padRight(value string, width int) string {
	if len(value) >= width {
		return value
	}
	return value + strings.Repeat(" ", width-len(value))
}

func clamp(value int, minValue int, maxValue int) int {
	if value < minValue {
		return minValue
	}
	if value > maxValue {
		return maxValue
	}
	return value
}

func (r renderer) formatKey(key string) string {
	return r.paint("2;38;5;245", key)
}

func (r renderer) formatService(service string) string {
	switch service {
	case "frontend":
		return r.paint("38;5;81", service)
	case "backend":
		return r.paint("38;5;114", service)
	case "db":
		return r.paint("38;5;222", service)
	case "watch":
		return r.paint("38;5;147", service)
	default:
		return r.paint("38;5;245", service)
	}
}

func (r renderer) formatLogoLine(_ int, line string) string {
	if !r.styled {
		return line
	}

	var out strings.Builder
	activeColor := ""
	for i := 0; i < len(line); i++ {
		color := logoGlyphColor(line[i])
		if color != activeColor {
			if activeColor != "" {
				out.WriteString("\033[0m")
			}
			if color != "" {
				out.WriteString("\033[")
				out.WriteString(color)
				out.WriteString("m")
			}
			activeColor = color
		}
		out.WriteByte(line[i])
	}
	if activeColor != "" {
		out.WriteString("\033[0m")
	}
	return out.String()
}

func (r renderer) formatLogoPacmanLine(line string, position int, step int) string {
	width := len(line)
	if position >= width {
		return r.formatLogoLine(0, line)
	}

	var out strings.Builder
	if position > 0 {
		out.WriteString(r.formatLogoLine(0, visiblePrefix(line, position)))
	}
	start := clamp(position, 0, width)
	for column := start; column < width; column++ {
		switch {
		case column == position:
			out.WriteString(r.formatLogoChomper(pacmanMouth(step, "right")))
		case isCandyPosition(column - position):
			out.WriteString(r.formatLogoPellet())
		default:
			out.WriteByte(' ')
		}
	}
	return out.String()
}

func (r renderer) formatLogoChomper(ch byte) string {
	return r.paint("1;38;5;226", string(ch))
}

func (r renderer) formatLogoPellet() string {
	return r.paint("2;38;5;220", "o")
}

func logoGlyphColor(ch byte) string {
	switch ch {
	case '_':
		return "2;38;5;245"
	case 'o', 'O', '0':
		return "38;5;220"
	default:
		return ""
	}
}

func (r renderer) formatValue(row outputRow) string {
	if !r.styled {
		return row.value
	}
	switch row.key {
	case "app", "api":
		return r.paint("38;5;81", row.value)
	case "error":
		return r.paint("38;5;203", row.value)
	default:
		return row.value
	}
}

func (r renderer) paint(code string, value string) string {
	if !r.styled {
		return value
	}
	return "\033[" + code + "m" + value + "\033[0m"
}

func rowKeyWidth(rows []outputRow) int {
	width := 0
	for _, row := range rows {
		if len(row.key) > width {
			width = len(row.key)
		}
	}
	return width
}

func logoLines(logo string) []string {
	logo = strings.TrimRight(logo, "\n")
	if strings.TrimSpace(logo) == "" {
		return nil
	}
	return strings.Split(logo, "\n")
}

func maxLineWidth(lines []string) int {
	width := 0
	for _, line := range lines {
		if len(line) > width {
			width = len(line)
		}
	}
	return width
}

func visiblePrefix(value string, width int) string {
	if width <= 0 {
		return ""
	}
	if width >= len(value) {
		return value
	}
	return value[:width]
}

func streamWatchOutput(input io.Reader, r renderer, logSink *devLogSink, stream string, wg *sync.WaitGroup) {
	defer wg.Done()
	scanner := bufio.NewScanner(input)
	scanner.Buffer(make([]byte, 1024), 1024*1024)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || line == "Watch enabled" {
			continue
		}
		entry := newStructuredLogEntry("compose-watch", stream, "watch", line)
		logSink.WriteEntry(entry)
		r.LogEntry(entry)
	}
}

func streamLogOutput(input io.Reader, r renderer, logSink *devLogSink, stream string, wg *sync.WaitGroup) {
	streamLogOutputWithQuery(input, r, logSink, stream, logQuery{}, wg)
}

func streamLogOutputWithQuery(input io.Reader, r renderer, logSink *devLogSink, stream string, query logQuery, wg *sync.WaitGroup) {
	defer wg.Done()
	scanner := bufio.NewScanner(input)
	scanner.Buffer(make([]byte, 1024), 1024*1024)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		service, message := parseComposeLogLine(line)
		entry := newStructuredLogEntry("compose-log", stream, service, message)
		logSink.WriteEntry(entry)
		if logEntryMatchesQuery(entry, query) {
			r.LogEntry(entry)
		}
	}
}

func newStructuredLogEntry(source string, stream string, service string, message string) structuredLogEntry {
	return structuredLogEntry{
		Time:    time.Now().UTC().Format(time.RFC3339Nano),
		Source:  source,
		Stream:  stream,
		Service: service,
		Message: message,
	}
}

func openDevLogSink(path string) (*devLogSink, error) {
	return openDevLogSinkWithFlags(path, os.O_CREATE|os.O_WRONLY|os.O_TRUNC)
}

func openAppendDevLogSink(path string) (*devLogSink, error) {
	return openDevLogSinkWithFlags(path, os.O_CREATE|os.O_WRONLY|os.O_APPEND)
}

func openDevLogSinkWithFlags(path string, flags int) (*devLogSink, error) {
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		return nil, err
	}
	file, err := os.OpenFile(path, flags, 0644)
	if err != nil {
		return nil, err
	}
	return &devLogSink{file: file, encoder: json.NewEncoder(file)}, nil
}

func (s *devLogSink) Close() error {
	if s == nil || s.file == nil {
		return nil
	}
	return s.file.Close()
}

func (s *devLogSink) Write(source string, stream string, service string, message string) {
	s.WriteEntry(newStructuredLogEntry(source, stream, service, message))
}

func (s *devLogSink) WriteEntry(entry structuredLogEntry) {
	if s == nil || s.encoder == nil || strings.TrimSpace(entry.Message) == "" {
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	_ = s.encoder.Encode(entry)
}

func (a app) commandLogs(args []string) error {
	if !isFile("carbide.toml") {
		return errors.New("run this inside a Carbide project")
	}
	query, err := parseLogQuery(args)
	if err != nil {
		return err
	}
	entries, err := readStructuredLogEntries(devLogPath)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return errors.New("no dev logs found; run carbide run dev first")
		}
		return err
	}
	entries = filterLogEntries(entries, query)
	entries = limitLogEntries(entries, query.limit)

	if query.json {
		encoder := json.NewEncoder(a.stdout)
		for _, entry := range entries {
			if err := encoder.Encode(entry); err != nil {
				return err
			}
		}
		return nil
	}

	r := newRenderer(a.stdout)
	for _, entry := range entries {
		r.LogEntry(entry)
	}
	return nil
}

func (a app) commandFollowLogs(args []string) error {
	if !isFile("carbide.toml") {
		return errors.New("run this inside a Carbide project")
	}
	query, err := parseLogQuery(args)
	if err != nil {
		return err
	}
	if query.json {
		return errors.New("carbide follow logs does not support json")
	}
	if query.limit != 80 {
		return errors.New("carbide follow logs does not support limit")
	}

	compose, err := findCompose()
	if err != nil {
		return err
	}
	env := setEnv(os.Environ(), "COMPOSE_MENU", "false")
	logSink, err := openAppendDevLogSink(devLogPath)
	if err != nil {
		return err
	}
	defer logSink.Close()

	var streams sync.WaitGroup
	results := make(chan processResult, 1)
	process, err := a.startComposeStream(
		"logs",
		compose,
		env,
		composeLogsArgs(compose),
		func(input io.Reader, r renderer, sink *devLogSink, stream string, wg *sync.WaitGroup) {
			streamLogOutputWithQuery(input, r, sink, stream, query, wg)
		},
		logSink,
		&streams,
		results,
	)
	if err != nil {
		return err
	}

	signals := make(chan os.Signal, 1)
	signal.Notify(signals, os.Interrupt, syscall.SIGTERM)
	defer signal.Stop(signals)

	var first processResult
	interrupted := false
	select {
	case sig := <-signals:
		interrupted = true
		logSink.Write("carbide", "lifecycle", "cli", "detached from dev logs")
		stopProcesses([]runningProcess{process}, sig)
	case first = <-results:
	}

	if interrupted {
		waitForProcesses(1, []runningProcess{process}, results, 5*time.Second)
		streams.Wait()
		r := newRenderer(a.stdout)
		r.Blank()
		r.Rows(outputRow{"logs", "detached"})
		return nil
	}
	streams.Wait()
	if first.err != nil {
		return fmt.Errorf("Docker Compose %s failed: %w", first.name, first.err)
	}
	return nil
}

func entryTimestamp(entry structuredLogEntry) time.Time {
	timestamp, err := time.Parse(time.RFC3339Nano, entry.Time)
	if err != nil {
		return time.Now()
	}
	return timestamp
}

func parseLogQuery(args []string) (logQuery, error) {
	query := logQuery{limit: 80}
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "service":
			i++
			if i >= len(args) || args[i] == "" {
				return query, errors.New("usage: carbide logs [service <name>] [containing <text>] [limit <count>] [json]")
			}
			query.service = args[i]
		case "containing":
			i++
			if i >= len(args) || args[i] == "" {
				return query, errors.New("usage: carbide logs [service <name>] [containing <text>] [limit <count>] [json]")
			}
			query.contains = args[i]
		case "limit":
			i++
			if i >= len(args) {
				return query, errors.New("usage: carbide logs [service <name>] [containing <text>] [limit <count>] [json]")
			}
			limit, err := strconv.Atoi(args[i])
			if err != nil || limit < 1 {
				return query, errors.New("log limit must be a positive number")
			}
			query.limit = limit
		case "json":
			query.json = true
		default:
			return query, fmt.Errorf("unknown logs option: %s", args[i])
		}
	}
	return query, nil
}

func readStructuredLogEntries(path string) ([]structuredLogEntry, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	var entries []structuredLogEntry
	scanner := bufio.NewScanner(file)
	scanner.Buffer(make([]byte, 1024), 1024*1024)
	lineNumber := 0
	for scanner.Scan() {
		lineNumber++
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		var entry structuredLogEntry
		if err := json.Unmarshal([]byte(line), &entry); err != nil {
			return nil, fmt.Errorf("invalid structured log line %d: %w", lineNumber, err)
		}
		entries = append(entries, entry)
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	return entries, nil
}

func filterLogEntries(entries []structuredLogEntry, query logQuery) []structuredLogEntry {
	filtered := make([]structuredLogEntry, 0, len(entries))
	for _, entry := range entries {
		if logEntryMatchesQuery(entry, query) {
			filtered = append(filtered, entry)
		}
	}
	return filtered
}

func logEntryMatchesQuery(entry structuredLogEntry, query logQuery) bool {
	if query.service != "" && entry.Service != query.service {
		return false
	}
	if query.contains != "" && !strings.Contains(strings.ToLower(entry.Message), strings.ToLower(query.contains)) {
		return false
	}
	return true
}

func limitLogEntries(entries []structuredLogEntry, limit int) []structuredLogEntry {
	if limit < 1 || len(entries) <= limit {
		return entries
	}
	return entries[len(entries)-limit:]
}

func carbideLogo(home string) string {
	if home != "" {
		content, err := os.ReadFile(filepath.Join(home, "logo.txt"))
		if err == nil && strings.TrimSpace(string(content)) != "" {
			return string(content)
		}
	}
	return defaultLogoText
}

func resolveHome() (string, error) {
	if home := os.Getenv("CARBIDE_HOME"); home != "" {
		return filepath.Abs(home)
	}

	exe, err := os.Executable()
	if err != nil {
		return "", err
	}
	exe, err = filepath.EvalSymlinks(exe)
	if err != nil {
		return "", err
	}

	dir := filepath.Dir(exe)
	switch filepath.Base(dir) {
	case "bin", ".bin":
		return filepath.Dir(dir), nil
	default:
		return filepath.Dir(dir), nil
	}
}

func shouldStyleOutput(w io.Writer) bool {
	if os.Getenv("NO_COLOR") != "" {
		return false
	}
	return isTerminalOutput(w)
}

func isTerminalOutput(w io.Writer) bool {
	file, ok := w.(*os.File)
	if !ok {
		return false
	}
	info, err := file.Stat()
	if err != nil {
		return false
	}
	return info.Mode()&os.ModeCharDevice != 0
}

type terminalWindowSize struct {
	rows    uint16
	columns uint16
	xpixels uint16
	ypixels uint16
}

func terminalColumns(w io.Writer) int {
	file, ok := w.(*os.File)
	if !ok {
		return 0
	}
	var size terminalWindowSize
	_, _, errno := syscall.Syscall(
		syscall.SYS_IOCTL,
		file.Fd(),
		uintptr(syscall.TIOCGWINSZ),
		uintptr(unsafe.Pointer(&size)),
	)
	if errno != 0 || size.columns == 0 {
		return 0
	}
	return int(size.columns)
}

func terminalColumnsFromEnv() int {
	columns, err := strconv.Atoi(os.Getenv("COLUMNS"))
	if err != nil || columns <= 0 {
		return 0
	}
	return columns
}

func ensureProjectName(name string) error {
	if name == "" || strings.HasPrefix(name, ".") || strings.ContainsAny(name, `/\`) {
		return errors.New("project name must be a simple directory name")
	}
	matched, err := regexp.MatchString(`^[A-Za-z0-9._-]+$`, name)
	if err != nil {
		return err
	}
	if !matched {
		return errors.New("project name may contain only letters, numbers, dots, underscores, and dashes")
	}
	return nil
}

func projectSlug(input string) string {
	var b strings.Builder
	lastDash := false
	for _, r := range strings.ToLower(input) {
		if r >= 'a' && r <= 'z' || r >= '0' && r <= '9' {
			b.WriteRune(r)
			lastDash = false
			continue
		}
		if !lastDash {
			b.WriteByte('-')
			lastDash = true
		}
	}
	return strings.Trim(b.String(), "-")
}

func (a app) copyTemplate(target string, name string, slug string) error {
	template := filepath.Join(a.home, "templates", "default")
	if !isDir(template) {
		return fmt.Errorf("missing template: %s", template)
	}

	return filepath.WalkDir(template, func(path string, entry fs.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}

		rel, err := filepath.Rel(template, path)
		if err != nil {
			return err
		}
		if rel == "." {
			return os.MkdirAll(target, 0755)
		}

		dest := filepath.Join(target, rel)
		info, err := entry.Info()
		if err != nil {
			return err
		}

		if entry.IsDir() {
			return os.MkdirAll(dest, info.Mode().Perm())
		}
		if entry.Type()&os.ModeSymlink != 0 {
			link, err := os.Readlink(path)
			if err != nil {
				return err
			}
			return os.Symlink(link, dest)
		}
		if !entry.Type().IsRegular() {
			return nil
		}

		content, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		content = bytes.ReplaceAll(content, []byte("__PROJECT_NAME__"), []byte(name))
		content = bytes.ReplaceAll(content, []byte("__PROJECT_SLUG__"), []byte(slug))
		return os.WriteFile(dest, content, info.Mode().Perm())
	})
}

func isCurrentDirEmpty() (bool, error) {
	entries, err := os.ReadDir(".")
	if err != nil {
		return false, err
	}
	return len(entries) == 0, nil
}

func findCompose() (composeCommand, error) {
	if _, err := commandOutput("", "docker", "compose", "version"); err == nil {
		help, _ := commandOutput("", "docker", "compose", "up", "--help")
		logHelp, _ := commandOutput("", "docker", "compose", "logs", "--help")
		return composeCommand{name: "docker", base: []string{"compose"}, help: help, logHelp: logHelp}, nil
	}
	if _, err := commandOutput("", "docker-compose", "version"); err == nil {
		help, _ := commandOutput("", "docker-compose", "up", "--help")
		logHelp, _ := commandOutput("", "docker-compose", "logs", "--help")
		return composeCommand{name: "docker-compose", help: help, logHelp: logHelp}, nil
	}
	return composeCommand{}, errors.New("Docker Compose is required for carbide run dev")
}

func (c composeCommand) args(extra ...string) []string {
	args := make([]string, 0, len(c.base)+len(extra))
	args = append(args, c.base...)
	args = append(args, extra...)
	return args
}

func (c composeCommand) supports(option string) bool {
	return strings.Contains(c.help, option)
}

func (c composeCommand) logsSupports(option string) bool {
	return strings.Contains(c.logHelp, option)
}

func composeServices(compose composeCommand, env []string) []string {
	output, err := runComposeCaptured(compose, env, "config", "--services")
	if err != nil {
		return defaultComposeServices()
	}
	seen := map[string]bool{}
	var services []string
	scanner := bufio.NewScanner(strings.NewReader(output))
	for scanner.Scan() {
		service := strings.TrimSpace(scanner.Text())
		if service == "" || seen[service] {
			continue
		}
		seen[service] = true
		services = append(services, service)
	}
	if len(services) == 0 {
		return defaultComposeServices()
	}
	return services
}

func defaultComposeServices() []string {
	return []string{"frontend", "backend", "db"}
}

func composeServiceStatuses(compose composeCommand, env []string) map[string]composeServiceStatus {
	snapshots, err := composeServiceSnapshots(compose, env)
	if err != nil {
		return nil
	}
	return composeStatusesFromSnapshots(snapshots)
}

func composeServiceSnapshots(compose composeCommand, env []string) (map[string]composeServiceSnapshot, error) {
	output, err := runComposeCaptured(compose, env, "ps", "--format", "json")
	if err != nil {
		return nil, err
	}
	return parseComposeServiceSnapshots(output)
}

func parseComposeServiceStatuses(output string) (map[string]composeServiceStatus, error) {
	snapshots, err := parseComposeServiceSnapshots(output)
	if err != nil {
		return nil, err
	}
	return composeStatusesFromSnapshots(snapshots), nil
}

func parseComposeServiceSnapshots(output string) (map[string]composeServiceSnapshot, error) {
	parseRecords := func(records []composeServiceSnapshot) map[string]composeServiceSnapshot {
		snapshots := map[string]composeServiceSnapshot{}
		for _, record := range records {
			service := strings.TrimSpace(record.Service)
			if service == "" {
				continue
			}
			record.Service = service
			record.Name = strings.TrimSpace(record.Name)
			record.State = strings.TrimSpace(record.State)
			record.Health = strings.TrimSpace(record.Health)
			record.Status = strings.TrimSpace(record.Status)
			record.Ports = strings.TrimSpace(record.Ports)
			snapshots[service] = record
		}
		return snapshots
	}

	var records []composeServiceSnapshot
	if err := json.Unmarshal([]byte(output), &records); err == nil {
		return parseRecords(records), nil
	}

	scanner := bufio.NewScanner(strings.NewReader(output))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		var record composeServiceSnapshot
		if err := json.Unmarshal([]byte(line), &record); err != nil {
			return nil, err
		}
		records = append(records, record)
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	return parseRecords(records), nil
}

func composeStatusesFromSnapshots(snapshots map[string]composeServiceSnapshot) map[string]composeServiceStatus {
	statuses := map[string]composeServiceStatus{}
	for service, snapshot := range snapshots {
		statuses[service] = composeServiceStatus{
			service: service,
			state:   snapshot.State,
			health:  snapshot.Health,
		}
	}
	return statuses
}

func composeStatusRow(snapshot composeServiceSnapshot) tableRow {
	return tableRow{
		snapshot.Service,
		statusValue(snapshot.Name),
		composePublishedPorts(snapshot),
		composeInternalPorts(snapshot),
		composeServiceStatusText(snapshot),
	}
}

func statusValue(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return "-"
	}
	return value
}

func composePublishedPorts(snapshot composeServiceSnapshot) string {
	seen := map[string]bool{}
	var ports []string
	for _, publisher := range snapshot.Publishers {
		if publisher.PublishedPort <= 0 {
			continue
		}
		host := strings.TrimSpace(publisher.URL)
		if host == "" || host == "0.0.0.0" || host == "::" {
			host = "localhost"
		}
		value := fmt.Sprintf("%s:%d", host, publisher.PublishedPort)
		if !seen[value] {
			seen[value] = true
			ports = append(ports, value)
		}
	}
	if len(ports) == 0 {
		return "-"
	}
	return strings.Join(ports, ", ")
}

func composeInternalPorts(snapshot composeServiceSnapshot) string {
	seen := map[string]bool{}
	var ports []string
	for _, publisher := range snapshot.Publishers {
		if publisher.TargetPort <= 0 {
			continue
		}
		protocol := strings.TrimSpace(publisher.Protocol)
		if protocol == "" {
			protocol = "tcp"
		}
		value := fmt.Sprintf("%d/%s", publisher.TargetPort, protocol)
		if !seen[value] {
			seen[value] = true
			ports = append(ports, value)
		}
	}
	if len(ports) == 0 && strings.TrimSpace(snapshot.Ports) != "" {
		return strings.TrimSpace(snapshot.Ports)
	}
	if len(ports) == 0 {
		return "-"
	}
	return strings.Join(ports, ", ")
}

func composeServiceStatusText(snapshot composeServiceSnapshot) string {
	state := strings.TrimSpace(strings.ToLower(snapshot.State))
	health := strings.TrimSpace(strings.ToLower(snapshot.Health))
	if state == "" {
		return statusValue(snapshot.Status)
	}
	if health != "" {
		return fmt.Sprintf("%s (%s)", state, health)
	}
	return state
}

func composeLogsArgs(compose composeCommand) []string {
	args := []string{"logs", "-f", "--tail", "80"}
	if compose.logsSupports("--no-color") {
		args = append(args, "--no-color")
	}
	return args
}

func parseComposeLogLine(line string) (string, string) {
	line = stripANSI(strings.TrimSpace(line))
	parts := strings.SplitN(line, "|", 2)
	if len(parts) != 2 {
		return "log", line
	}
	service := normalizeServiceName(strings.TrimSpace(parts[0]))
	message := strings.TrimSpace(parts[1])
	return service, message
}

func normalizeServiceName(name string) string {
	name = strings.TrimSpace(name)
	if name == "" {
		return "log"
	}
	parts := strings.Split(name, "-")
	if len(parts) > 1 {
		last := parts[len(parts)-1]
		if _, err := strconv.Atoi(last); err == nil {
			name = strings.Join(parts[:len(parts)-1], "-")
		}
	}
	if idx := strings.LastIndex(name, "-"); idx >= 0 {
		name = name[idx+1:]
	}
	switch name {
	case "frontend", "backend", "db":
		return name
	default:
		return name
	}
}

func stripANSI(value string) string {
	var out strings.Builder
	inEscape := false
	inCSI := false
	for i := 0; i < len(value); i++ {
		ch := value[i]
		if inEscape {
			if !inCSI && ch == '[' {
				inCSI = true
				continue
			}
			if inCSI {
				if ch >= '@' && ch <= '~' {
					inEscape = false
					inCSI = false
				}
				continue
			}
			if ch >= 0x30 && ch <= 0x7e {
				inEscape = false
			}
			continue
		}
		if ch == 0x1b {
			inEscape = true
			continue
		}
		out.WriteByte(ch)
	}
	return out.String()
}

func composeUpDetached(compose composeCommand, env []string) error {
	args := []string{"up", "-d", "--build", "--remove-orphans"}
	if compose.supports("--quiet-build") {
		args = append(args, "--quiet-build")
	}
	if compose.supports("--quiet-pull") {
		args = append(args, "--quiet-pull")
	}
	if compose.supports("--wait") {
		args = append(args, "--wait", "--wait-timeout", "120")
	}
	output, err := runComposeCaptured(compose, env, args...)
	if err != nil {
		return fmt.Errorf("Docker Compose start failed: %w\n%s", err, strings.TrimSpace(output))
	}
	return nil
}

func composeDown(compose composeCommand, env []string) error {
	output, err := runComposeCaptured(compose, env, "down", "--remove-orphans")
	if err != nil {
		return fmt.Errorf("Docker Compose cleanup failed: %w\n%s", err, strings.TrimSpace(output))
	}
	return nil
}

func runComposeCaptured(compose composeCommand, env []string, args ...string) (string, error) {
	cmd := exec.Command(compose.name, compose.args(args...)...)
	cmd.Env = env
	var output bytes.Buffer
	cmd.Stdout = &output
	cmd.Stderr = &output
	err := cmd.Run()
	return output.String(), err
}

func validatePort(value string) (int, error) {
	if value == "" {
		return 0, errors.New("CARBIDE_HTTP_PORT must be a number from 1 to 65535")
	}
	port, err := strconv.Atoi(value)
	if err != nil || port < 1 || port > 65535 {
		return 0, errors.New("CARBIDE_HTTP_PORT must be a number from 1 to 65535")
	}
	return port, nil
}

func chooseDevPort(requested string) (int, error) {
	if requested != "" {
		port, err := validatePort(requested)
		if err != nil {
			return 0, err
		}
		if !portIsAvailable(port) {
			return 0, fmt.Errorf("port %d is already in use; choose another with CARBIDE_HTTP_PORT=<port> carbide run dev", port)
		}
		return port, nil
	}

	for _, port := range []int{8080, 8081, 8082, 8083, 8084, 8085, 18080, 18081, 18082, 18083, 18084, 18085} {
		if portIsAvailable(port) {
			return port, nil
		}
	}
	return 0, errors.New("no free dev port found; run with CARBIDE_HTTP_PORT=<port> carbide run dev")
}

func portIsAvailable(port int) bool {
	listener, err := net.Listen("tcp", fmt.Sprintf("0.0.0.0:%d", port))
	if err != nil {
		return false
	}
	_ = listener.Close()
	return true
}

func buildInstalledBinary(home string) error {
	if _, err := exec.LookPath("go"); err != nil {
		return errors.New("Go is required to build the Carbide CLI")
	}

	outDir := filepath.Join(home, ".bin")
	if err := os.MkdirAll(outDir, 0755); err != nil {
		return err
	}

	finalPath := filepath.Join(outDir, "carbide")
	tmpPath := filepath.Join(outDir, fmt.Sprintf(".carbide-%d", os.Getpid()))
	ldflags := "-X github.com/ryangerardwilson/carbide/internal/carbide.commit=" + gitShortHead(home)

	cmd := exec.Command("go", "build", "-ldflags", ldflags, "-o", tmpPath, "./cmd/carbide")
	cmd.Dir = home
	var output bytes.Buffer
	cmd.Stdout = &output
	cmd.Stderr = &output
	if err := cmd.Run(); err != nil {
		_ = os.Remove(tmpPath)
		return fmt.Errorf("Go build failed: %w\n%s", err, strings.TrimSpace(output.String()))
	}
	if err := os.Chmod(tmpPath, 0755); err != nil {
		_ = os.Remove(tmpPath)
		return err
	}
	if err := os.Rename(tmpPath, finalPath); err != nil {
		_ = os.Remove(tmpPath)
		return err
	}
	return nil
}

func commandOutput(dir string, name string, args ...string) (string, error) {
	cmd := exec.Command(name, args...)
	if dir != "" {
		cmd.Dir = dir
	}
	var output bytes.Buffer
	cmd.Stdout = &output
	cmd.Stderr = &output
	if err := cmd.Run(); err != nil {
		text := strings.TrimSpace(output.String())
		if text != "" {
			return "", fmt.Errorf("%s %s failed: %w\n%s", name, strings.Join(args, " "), err, text)
		}
		return "", err
	}
	return strings.TrimSpace(output.String()), nil
}

func gitShortHead(dir string) string {
	head, err := commandOutput(dir, "git", "rev-parse", "--short", "HEAD")
	if err != nil {
		return ""
	}
	return head
}

func setEnv(env []string, key string, value string) []string {
	prefix := key + "="
	out := make([]string, 0, len(env)+1)
	set := false
	for _, item := range env {
		if strings.HasPrefix(item, prefix) {
			out = append(out, prefix+value)
			set = true
			continue
		}
		out = append(out, item)
	}
	if !set {
		out = append(out, prefix+value)
	}
	return out
}

func isFile(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.Mode().IsRegular()
}

func isDir(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}
