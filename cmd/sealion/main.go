package main

import (
	"bytes"
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
	"syscall"
	"time"
)

var version = "0.1.0-dev"
var commit = ""

const helpText = `Sealion
Containerized full-stack apps with React, C, and Postgres.

global actions:
  sealion help
    show this help
  sealion version
    print the installed version
  sealion upgrade
    upgrade the installed CLI from GitHub when a newer commit is available

features:
  install the CLI from GitHub
  # curl -fsSL <github-install-url> | bash
  curl -fsSL https://raw.githubusercontent.com/ryangerardwilson/sealion/main/install.sh | bash

  create a new project directory
  # sealion new <project-name>
  sealion new demo

  initialize the current empty directory
  # sealion init
  mkdir demo && cd demo && sealion init

  run the local development stack
  # sealion run dev
  cd demo && sealion run dev
`

type app struct {
	home   string
	stdout io.Writer
	stderr io.Writer
}

type composeCommand struct {
	name string
	base []string
	help string
}

func main() {
	home, err := resolveHome()
	if err != nil {
		fmt.Fprintf(os.Stderr, "sealion: %v\n", err)
		os.Exit(1)
	}

	a := app{
		home:   home,
		stdout: os.Stdout,
		stderr: os.Stderr,
	}

	if err := a.run(os.Args[1:]); err != nil {
		fmt.Fprintf(os.Stderr, "sealion: %v\n", err)
		os.Exit(1)
	}
}

func (a app) run(args []string) error {
	if len(args) == 0 {
		a.printHelp()
		return nil
	}

	switch args[0] {
	case "help", "-h", "--help":
		if len(args) != 1 {
			return errors.New("usage: sealion help")
		}
		a.printHelp()
		return nil
	case "version":
		if len(args) != 1 {
			return errors.New("usage: sealion version")
		}
		return a.commandVersion()
	case "upgrade":
		if len(args) != 1 {
			return errors.New("usage: sealion upgrade")
		}
		return a.commandUpgrade()
	case "new":
		if len(args) != 2 {
			return errors.New("usage: sealion new <project-name>")
		}
		return a.commandNew(args[1])
	case "init":
		if len(args) != 1 {
			return errors.New("usage: sealion init")
		}
		return a.commandInit()
	case "run":
		if len(args) == 2 && args[1] == "dev" {
			return a.commandRunDev()
		}
		return errors.New("usage: sealion run dev")
	default:
		return fmt.Errorf("unknown command: %s", args[0])
	}
}

func (a app) printHelp() {
	if shouldStyleHelp(a.stdout) {
		fmt.Fprintf(a.stdout, "\033[38;5;245m%s\033[0m", helpText)
		return
	}
	fmt.Fprint(a.stdout, helpText)
}

func (a app) commandVersion() error {
	label := version
	if commit != "" {
		label = fmt.Sprintf("%s (%s)", label, commit)
	} else if head := gitShortHead(a.home); head != "" {
		label = fmt.Sprintf("%s (%s)", label, head)
	}
	fmt.Fprintf(a.stdout, "sealion %s\n", label)
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
		slug = "sealion-app"
	}
	if err := a.copyTemplate(target, name, slug); err != nil {
		return err
	}

	fmt.Fprintf(a.stdout, "created %s\n", target)
	fmt.Fprintln(a.stdout, "next:")
	fmt.Fprintf(a.stdout, "  cd %s\n", name)
	fmt.Fprintln(a.stdout, "  sealion run dev")
	return nil
}

func (a app) commandInit() error {
	empty, err := isCurrentDirEmpty()
	if err != nil {
		return err
	}
	if !empty {
		return errors.New("sealion init requires an empty directory")
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
		slug = "sealion-app"
	}
	if err := a.copyTemplate(pwd, name, slug); err != nil {
		return err
	}

	fmt.Fprintf(a.stdout, "initialized %s\n", pwd)
	fmt.Fprintln(a.stdout, "next:")
	fmt.Fprintln(a.stdout, "  sealion run dev")
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
			fmt.Fprintf(a.stdout, "sealion is already up to date (%s)\n", currentHead)
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
		fmt.Fprintf(a.stdout, "upgraded sealion %s -> %s\n", currentHead, newHead)
		return nil
	}

	installScript := filepath.Join(a.home, "install.sh")
	if !isFile(installScript) {
		return errors.New("cannot find install.sh for this Sealion installation")
	}
	cmd := exec.Command("bash", installScript)
	cmd.Env = append(os.Environ(), "SEALION_HOME="+a.home)
	cmd.Stdin = os.Stdin
	cmd.Stdout = a.stdout
	cmd.Stderr = a.stderr
	return cmd.Run()
}

func (a app) commandRunDev() error {
	if !isFile("sealion.toml") {
		return errors.New("run this inside a Sealion project")
	}

	compose, err := findCompose()
	if err != nil {
		return err
	}

	requestedPort := os.Getenv("SEALION_HTTP_PORT")
	port, err := chooseDevPort(requestedPort)
	if err != nil {
		return err
	}

	env := setEnv(os.Environ(), "SEALION_HTTP_PORT", strconv.Itoa(port))
	env = setEnv(env, "COMPOSE_MENU", "false")
	watch := compose.supports("--watch")

	a.printDevHeader(port, requestedPort, watch)
	fmt.Fprintln(a.stdout, "status  starting containers")
	if err := composeUpDetached(compose, env); err != nil {
		return err
	}
	fmt.Fprintln(a.stdout, "status  ready")

	if !watch {
		fmt.Fprintln(a.stdout, "watch   unavailable in this Docker Compose")
		fmt.Fprintln(a.stdout, "logs    docker compose logs -f")
		fmt.Fprintln(a.stdout, "stop    docker compose down")
		return nil
	}

	fmt.Fprintln(a.stdout, "watch   enabled")
	fmt.Fprintln(a.stdout, "logs    docker compose logs -f")
	fmt.Fprintln(a.stdout, "stop    Ctrl+C")
	fmt.Fprintln(a.stdout)

	return a.runComposeWatch(compose, env)
}

func (a app) printDevHeader(port int, requestedPort string, watch bool) {
	fmt.Fprintln(a.stdout, "Sealion dev")
	fmt.Fprintln(a.stdout)
	if requestedPort == "" && port != 8080 {
		fmt.Fprintf(a.stdout, "port    8080 busy, using %d\n", port)
	}
	fmt.Fprintf(a.stdout, "app     http://localhost:%d\n", port)
	fmt.Fprintf(a.stdout, "api     http://localhost:%d/api\n", port)
	fmt.Fprintln(a.stdout, "login   admin@sealion.local / password")
	if watch {
		fmt.Fprintln(a.stdout, "mode    build, start, and watch")
	} else {
		fmt.Fprintln(a.stdout, "mode    build and start")
	}
}

func (a app) runComposeWatch(compose composeCommand, env []string) error {
	cmd := exec.Command(compose.name, compose.args("watch", "--no-up", "--quiet")...)
	cmd.Env = env
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("Docker Compose watch failed to start: %w", err)
	}

	done := make(chan error, 1)
	go func() {
		done <- cmd.Wait()
	}()

	signals := make(chan os.Signal, 1)
	signal.Notify(signals, os.Interrupt, syscall.SIGTERM)
	defer signal.Stop(signals)

	var watchErr error
	interrupted := false

	select {
	case sig := <-signals:
		interrupted = true
		fmt.Fprintln(a.stdout)
		fmt.Fprintln(a.stdout, "status  stopping containers")
		_ = cmd.Process.Signal(sig)
		select {
		case watchErr = <-done:
		case <-time.After(5 * time.Second):
			_ = cmd.Process.Kill()
			watchErr = <-done
		}
	case watchErr = <-done:
	}

	downErr := composeDown(compose, env)
	if interrupted {
		return downErr
	}
	if watchErr != nil {
		if downErr != nil {
			return fmt.Errorf("Docker Compose watch failed: %v; cleanup failed: %w", watchErr, downErr)
		}
		return fmt.Errorf("Docker Compose watch failed: %w", watchErr)
	}
	return downErr
}

func resolveHome() (string, error) {
	if home := os.Getenv("SEALION_HOME"); home != "" {
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

func shouldStyleHelp(w io.Writer) bool {
	if os.Getenv("NO_COLOR") != "" {
		return false
	}
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
		return composeCommand{name: "docker", base: []string{"compose"}, help: help}, nil
	}
	if _, err := commandOutput("", "docker-compose", "version"); err == nil {
		help, _ := commandOutput("", "docker-compose", "up", "--help")
		return composeCommand{name: "docker-compose", help: help}, nil
	}
	return composeCommand{}, errors.New("Docker Compose is required for sealion run dev")
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
		return 0, errors.New("SEALION_HTTP_PORT must be a number from 1 to 65535")
	}
	port, err := strconv.Atoi(value)
	if err != nil || port < 1 || port > 65535 {
		return 0, errors.New("SEALION_HTTP_PORT must be a number from 1 to 65535")
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
			return 0, fmt.Errorf("port %d is already in use; choose another with SEALION_HTTP_PORT=<port> sealion run dev", port)
		}
		return port, nil
	}

	for _, port := range []int{8080, 8081, 8082, 8083, 8084, 8085, 18080, 18081, 18082, 18083, 18084, 18085} {
		if portIsAvailable(port) {
			return port, nil
		}
	}
	return 0, errors.New("no free dev port found; run with SEALION_HTTP_PORT=<port> sealion run dev")
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
		return errors.New("Go is required to build the Sealion CLI")
	}

	outDir := filepath.Join(home, ".bin")
	if err := os.MkdirAll(outDir, 0755); err != nil {
		return err
	}

	finalPath := filepath.Join(outDir, "sealion")
	tmpPath := filepath.Join(outDir, fmt.Sprintf(".sealion-%d", os.Getpid()))
	ldflags := "-X main.commit=" + gitShortHead(home)

	cmd := exec.Command("go", "build", "-ldflags", ldflags, "-o", tmpPath, "./cmd/sealion")
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
