import React, { useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import './styles.css';

const APP_NAME = import.meta.env.VITE_APP_NAME || '__PROJECT_NAME__';
const DEMO_EMAIL = 'admin@sealion.local';
const DEMO_PASSWORD = 'password';

async function api(path, options = {}) {
  const response = await fetch(path, {
    credentials: 'include',
    ...options,
    headers: {
      ...(options.body ? { 'Content-Type': 'application/x-www-form-urlencoded' } : {}),
      ...(options.headers || {})
    }
  });
  const data = await response.json();
  if (!response.ok) {
    throw new Error(data.error || 'Request failed.');
  }
  return data;
}

function encodeForm(values) {
  const params = new URLSearchParams();
  Object.entries(values).forEach(([key, value]) => params.set(key, value));
  return params.toString();
}

function useRoute() {
  const [route, setRouteState] = useState(window.location.pathname);

  useEffect(() => {
    const onPop = () => setRouteState(window.location.pathname);
    window.addEventListener('popstate', onPop);
    return () => window.removeEventListener('popstate', onPop);
  }, []);

  const setRoute = (next) => {
    if (window.location.pathname !== next) {
      window.history.pushState({}, '', next);
    }
    setRouteState(next);
  };

  return [route, setRoute];
}

function AuthForm({ mode, onSubmit, busy, error, onMode }) {
  const isRegister = mode === 'register';
  const [email, setEmail] = useState(isRegister ? '' : DEMO_EMAIL);
  const [password, setPassword] = useState(isRegister ? '' : DEMO_PASSWORD);

  useEffect(() => {
    setEmail(isRegister ? '' : DEMO_EMAIL);
    setPassword(isRegister ? '' : DEMO_PASSWORD);
  }, [isRegister]);

  return (
    <form
      className="auth-form"
      onSubmit={(event) => {
        event.preventDefault();
        onSubmit({ email, password });
      }}
    >
      <div>
        <p className="eyebrow">Sealion starter</p>
        <h1>{isRegister ? 'Create your account' : 'Log in to the dashboard'}</h1>
        <p className="muted">
          React owns this interface. The C backend owns auth, sessions, and Postgres state.
        </p>
      </div>

      {error ? <p className="error">{error}</p> : null}

      <label>
        Email
        <input
          name="email"
          type="email"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          autoComplete="email"
          required
        />
      </label>

      <label>
        Password
        <input
          name="password"
          type="password"
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          autoComplete={isRegister ? 'new-password' : 'current-password'}
          required
        />
      </label>

      <button type="submit" disabled={busy}>
        {busy ? 'Working...' : isRegister ? 'Create account' : 'Log in'}
      </button>

      <p className="switcher">
        {isRegister ? 'Already registered?' : 'Need an account?'}{' '}
        <button type="button" onClick={() => onMode(isRegister ? 'login' : 'register')}>
          {isRegister ? 'Log in' : 'Create one'}
        </button>
      </p>

      {!isRegister ? (
        <p className="hint">
          Demo login: <code>{DEMO_EMAIL}</code> / <code>{DEMO_PASSWORD}</code>
        </p>
      ) : null}
    </form>
  );
}

function Dashboard({ user, onLogout, busy }) {
  return (
    <main className="workspace">
      <header className="topbar">
        <div>
          <p className="eyebrow">React frontend + C API + Postgres</p>
          <h1>{APP_NAME}</h1>
        </div>
        <button type="button" onClick={onLogout} disabled={busy}>
          {busy ? 'Logging out...' : 'Log out'}
        </button>
      </header>

      <section className="status-grid" aria-label="Application status">
        <div>
          <span>Frontend</span>
          <strong>React container</strong>
        </div>
        <div>
          <span>Backend</span>
          <strong>C API container</strong>
        </div>
        <div>
          <span>Database</span>
          <strong>Postgres container</strong>
        </div>
      </section>

      <section className="dashboard-panel">
        <p className="eyebrow">Session</p>
        <h2>Logged in as {user.email}</h2>
        <p>
          The browser talks to <code>/api</code> on the same origin. Vite proxies those requests
          to the C backend, and the backend persists the session in Postgres.
        </p>
      </section>
    </main>
  );
}

function App() {
  const [route, setRoute] = useRoute();
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const mode = useMemo(() => (route === '/register' ? 'register' : 'login'), [route]);

  useEffect(() => {
    api('/api/me')
      .then((data) => {
        if (data.authenticated) {
          setUser(data.user);
          if (window.location.pathname === '/' || window.location.pathname === '/login') {
            setRoute('/dashboard');
          }
        } else if (window.location.pathname === '/dashboard') {
          setRoute('/login');
        }
      })
      .finally(() => setLoading(false));
  }, []);

  const submitAuth = async ({ email, password }) => {
    setBusy(true);
    setError('');
    try {
      const data = await api(`/api/${mode}`, {
        method: 'POST',
        body: encodeForm({ email, password })
      });
      setUser(data.user);
      setRoute('/dashboard');
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  const logout = async () => {
    setBusy(true);
    try {
      await api('/api/logout', { method: 'POST' });
      setUser(null);
      setRoute('/login');
    } finally {
      setBusy(false);
    }
  };

  if (loading) {
    return (
      <main className="centered">
        <p className="eyebrow">Sealion</p>
        <h1>Loading app state</h1>
      </main>
    );
  }

  if (route === '/dashboard' && user) {
    return <Dashboard user={user} onLogout={logout} busy={busy} />;
  }

  return (
    <main className="auth-shell">
      <section className="product-pane">
        <p className="eyebrow">__PROJECT_NAME__</p>
        <h1>Containerized full stack development, with C where it matters.</h1>
        <p>
          Run one command. Get a React frontend, a C API backend, and a Postgres database
          wired together with same-origin auth.
        </p>
      </section>

      <AuthForm
        mode={mode}
        onSubmit={submitAuth}
        busy={busy}
        error={error}
        onMode={(nextMode) => {
          setError('');
          setRoute(nextMode === 'register' ? '/register' : '/login');
        }}
      />
    </main>
  );
}

createRoot(document.getElementById('root')).render(<App />);
