package model

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Store struct {
	Pool *pgxpool.Pool
}

type User struct {
	ID    int    `json:"id"`
	Email string `json:"email"`
}

func Connect(ctx context.Context) (*Store, error) {
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		databaseURL = "postgres://carbide:carbide@localhost:5432/carbide"
	}

	var lastErr error
	for attempt := 1; attempt <= 30; attempt++ {
		pool, err := pgxpool.New(ctx, databaseURL)
		if err == nil {
			pingCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
			err = pool.Ping(pingCtx)
			cancel()
			if err == nil {
				store := &Store{Pool: pool}
				if err := store.ensureSchema(ctx); err != nil {
					pool.Close()
					return nil, err
				}
				return store, nil
			}
			pool.Close()
		}

		lastErr = err
		fmt.Fprintf(os.Stderr, "waiting for postgres (%d/30): %v\n", attempt, lastErr)
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(time.Second):
		}
	}

	return nil, fmt.Errorf("could not connect to postgres: %w", lastErr)
}

func (s *Store) Close() {
	if s != nil && s.Pool != nil {
		s.Pool.Close()
	}
}

func (s *Store) ensureSchema(ctx context.Context) error {
	statements := []string{
		`CREATE TABLE IF NOT EXISTS users (
			id SERIAL PRIMARY KEY,
			email TEXT NOT NULL UNIQUE,
			password_hash TEXT NOT NULL,
			password_salt TEXT NOT NULL,
			created_at TIMESTAMPTZ NOT NULL DEFAULT now()
		)`,
		`CREATE TABLE IF NOT EXISTS sessions (
			token TEXT PRIMARY KEY,
			user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
			created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
			expires_at TIMESTAMPTZ NOT NULL
		)`,
		`CREATE INDEX IF NOT EXISTS sessions_user_id_idx ON sessions(user_id)`,
		`CREATE INDEX IF NOT EXISTS sessions_expires_at_idx ON sessions(expires_at)`,
		`DELETE FROM sessions WHERE expires_at < now()`,
	}

	for _, statement := range statements {
		if _, err := s.Pool.Exec(ctx, statement); err != nil {
			return err
		}
	}
	return nil
}

func NormalizeEmail(email string) string {
	return strings.ToLower(strings.TrimSpace(email))
}

func (s *Store) CreateUser(ctx context.Context, email string, password string) error {
	email = NormalizeEmail(email)
	if len(email) < 3 || !strings.Contains(email, "@") {
		return errors.New("Enter a valid email address.")
	}
	if len(password) < 6 {
		return errors.New("Password must be at least 6 characters.")
	}

	salt, err := randomHex(16)
	if err != nil {
		return err
	}
	hash := passwordHash(password, salt)

	if _, err := s.Pool.Exec(
		ctx,
		`INSERT INTO users(email, password_hash, password_salt) VALUES($1, $2, $3)`,
		email,
		hash,
		salt,
	); err != nil {
		return errors.New("That email is already registered.")
	}
	return nil
}

func (s *Store) VerifyUser(ctx context.Context, email string, password string) (int, bool, error) {
	email = NormalizeEmail(email)
	var id int
	var storedHash string
	var salt string

	err := s.Pool.QueryRow(
		ctx,
		`SELECT id, password_hash, password_salt FROM users WHERE email = $1`,
		email,
	).Scan(&id, &storedHash, &salt)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, false, nil
	}
	if err != nil {
		return 0, false, err
	}
	return id, passwordHash(password, salt) == storedHash, nil
}

func (s *Store) LookupUserID(ctx context.Context, email string) (int, bool, error) {
	email = NormalizeEmail(email)
	var id int
	err := s.Pool.QueryRow(ctx, `SELECT id FROM users WHERE email = $1`, email).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, false, nil
	}
	if err != nil {
		return 0, false, err
	}
	return id, true, nil
}

func randomHex(byteCount int) (string, error) {
	bytes := make([]byte, byteCount)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return hex.EncodeToString(bytes), nil
}

func passwordHash(password string, salt string) string {
	sum := sha256.Sum256([]byte(salt + ":" + password))
	return hex.EncodeToString(sum[:])
}
