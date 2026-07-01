package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"carbideapp/controller"
	"carbideapp/model"
)

const appName = "__PROJECT_NAME__"

func main() {
	port := envInt("APP_PORT", 8080)
	publicURL := os.Getenv("PUBLIC_URL")

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	store, err := model.Connect(ctx)
	if err != nil {
		log.Fatalf("database startup failed: %v", err)
	}
	defer store.Close()

	mux := http.NewServeMux()
	controller.RegisterRoutes(mux, store)

	server := &http.Server{
		Addr:              fmt.Sprintf(":%d", port),
		Handler:           logRequests(mux),
		ReadHeaderTimeout: 5 * time.Second,
	}

	fmt.Printf("%s backend listening on container port %d\n", appName, port)
	if publicURL != "" {
		fmt.Printf("public API URL is %s/api\n", publicURL)
	}

	errs := make(chan error, 1)
	go func() {
		errs <- server.ListenAndServe()
	}()

	select {
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := server.Shutdown(shutdownCtx); err != nil {
			log.Printf("server shutdown failed: %v", err)
		}
	case err := <-errs:
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("server failed: %v", err)
		}
	}
}

func envInt(name string, fallback int) int {
	value := os.Getenv(name)
	if value == "" {
		return fallback
	}
	parsed, err := strconv.Atoi(value)
	if err != nil || parsed < 1 {
		return fallback
	}
	return parsed
}

func logRequests(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Printf("%s %s\n", r.Method, r.URL.Path)
		next.ServeHTTP(w, r)
	})
}
