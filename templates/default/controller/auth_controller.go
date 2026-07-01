package controller

import (
	"net/http"
	"time"

	"carbideapp/model"
)

const sessionCookie = "carbide_session"

func (a *App) handleRegister(w http.ResponseWriter, r *http.Request) {
	if !requireMethod(w, r, http.MethodPost) {
		return
	}
	if err := r.ParseForm(); err != nil {
		respondAuthError(w, "Could not read the form.")
		return
	}

	email := model.NormalizeEmail(r.FormValue("email"))
	password := r.FormValue("password")
	if err := a.Store.CreateUser(r.Context(), email, password); err != nil {
		respondAuthError(w, err.Error())
		return
	}

	userID, ok, err := a.Store.LookupUserID(r.Context(), email)
	if err != nil || !ok {
		respondAuthError(w, "Account created, but login failed. Try logging in.")
		return
	}
	token, err := a.Store.CreateSession(r.Context(), userID)
	if err != nil {
		respondAuthError(w, "Account created, but login failed. Try logging in.")
		return
	}
	respondUserSession(w, email, token)
}

func (a *App) handleLogin(w http.ResponseWriter, r *http.Request) {
	if !requireMethod(w, r, http.MethodPost) {
		return
	}
	if err := r.ParseForm(); err != nil {
		respondAuthError(w, "Could not read the form.")
		return
	}

	email := model.NormalizeEmail(r.FormValue("email"))
	userID, ok, err := a.Store.VerifyUser(r.Context(), email, r.FormValue("password"))
	if err != nil || !ok {
		respondAuthError(w, "Email or password is incorrect.")
		return
	}
	token, err := a.Store.CreateSession(r.Context(), userID)
	if err != nil {
		respondAuthError(w, "Could not create a session.")
		return
	}
	respondUserSession(w, email, token)
}

func (a *App) handleLogout(w http.ResponseWriter, r *http.Request) {
	if !requireMethod(w, r, http.MethodPost) {
		return
	}
	if cookie, err := r.Cookie(sessionCookie); err == nil {
		_ = a.Store.DestroySession(r.Context(), cookie.Value)
	}
	http.SetCookie(w, &http.Cookie{
		Name:     sessionCookie,
		Value:    "deleted",
		Path:     "/",
		MaxAge:   -1,
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
	})
	respondJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func respondAuthError(w http.ResponseWriter, message string) {
	respondJSON(w, http.StatusUnprocessableEntity, map[string]any{
		"ok":    false,
		"error": message,
	})
}

func respondUserSession(w http.ResponseWriter, email string, token string) {
	http.SetCookie(w, &http.Cookie{
		Name:     sessionCookie,
		Value:    token,
		Path:     "/",
		MaxAge:   int((7 * 24 * time.Hour).Seconds()),
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
	})
	respondJSON(w, http.StatusOK, map[string]any{
		"ok":   true,
		"user": map[string]string{"email": email},
	})
}
