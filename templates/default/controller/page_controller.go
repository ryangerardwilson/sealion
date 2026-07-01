package controller

import (
	"encoding/json"
	"net/http"

	"carbideapp/model"
)

type App struct {
	Store *model.Store
}

func RegisterRoutes(mux *http.ServeMux, store *model.Store) {
	app := &App{Store: store}
	mux.HandleFunc("/health", app.handleHealth)
	mux.HandleFunc("/api/health", app.handleAPIHealth)
	mux.HandleFunc("/api/me", app.handleMe)
	mux.HandleFunc("/api/dashboard", app.handleDashboard)
	mux.HandleFunc("/api/register", app.handleRegister)
	mux.HandleFunc("/api/login", app.handleLogin)
	mux.HandleFunc("/api/logout", app.handleLogout)
	mux.HandleFunc("/", app.handleNotFound)
}

func (a *App) handleHealth(w http.ResponseWriter, r *http.Request) {
	if !requireMethod(w, r, http.MethodGet) {
		return
	}
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	_, _ = w.Write([]byte("ok\n"))
}

func (a *App) handleAPIHealth(w http.ResponseWriter, r *http.Request) {
	if !requireMethod(w, r, http.MethodGet) {
		return
	}
	respondJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (a *App) handleMe(w http.ResponseWriter, r *http.Request) {
	if !requireMethod(w, r, http.MethodGet) {
		return
	}
	user, ok, err := a.currentUser(r)
	if err != nil {
		respondJSON(w, http.StatusInternalServerError, map[string]any{"authenticated": false, "user": nil})
		return
	}
	if !ok {
		respondJSON(w, http.StatusOK, map[string]any{"authenticated": false, "user": nil})
		return
	}
	respondJSON(w, http.StatusOK, map[string]any{
		"authenticated": true,
		"user":          map[string]string{"email": user.Email},
	})
}

func (a *App) handleDashboard(w http.ResponseWriter, r *http.Request) {
	if !requireMethod(w, r, http.MethodGet) {
		return
	}
	user, ok, err := a.currentUser(r)
	if err != nil || !ok {
		respondJSON(w, http.StatusUnauthorized, map[string]any{
			"ok":    false,
			"error": "Authentication required.",
		})
		return
	}
	respondJSON(w, http.StatusOK, map[string]any{
		"ok":      true,
		"user":    map[string]string{"email": user.Email},
		"message": "This dashboard is backed by the Go API and Postgres.",
	})
}

func (a *App) handleNotFound(w http.ResponseWriter, r *http.Request) {
	respondJSON(w, http.StatusNotFound, map[string]any{
		"ok":    false,
		"error": "Route not found.",
	})
}

func (a *App) currentUser(r *http.Request) (model.User, bool, error) {
	cookie, err := r.Cookie(sessionCookie)
	if err != nil || cookie.Value == "" {
		return model.User{}, false, nil
	}
	return a.Store.CurrentUser(r.Context(), cookie.Value)
}

func requireMethod(w http.ResponseWriter, r *http.Request, method string) bool {
	if r.Method == method {
		return true
	}
	respondJSON(w, http.StatusMethodNotAllowed, map[string]any{
		"ok":    false,
		"error": "Method not allowed.",
	})
	return false
}

func respondJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}
