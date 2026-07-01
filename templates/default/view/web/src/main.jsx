import React, { useEffect, useMemo, useState } from 'react';
import { createRoot } from 'react-dom/client';
import './tailwind.css';

const APP_NAME = '__PROJECT_NAME__';

const buttonClass =
  'inline-flex min-h-11 items-center justify-center bg-teal-700 px-5 font-bold text-white transition hover:bg-teal-800 disabled:opacity-65';
const linkButtonClass =
  'inline bg-transparent p-0 font-bold text-teal-700 underline-offset-4 hover:underline';
const inputClass =
  'min-h-12 w-full border border-emerald-900/20 bg-white px-3 py-2 text-[#16211b] outline-none transition focus:border-teal-700 focus:ring-4 focus:ring-teal-700/15';
const eyebrowClass = 'mb-2 text-xs font-extrabold uppercase tracking-normal text-teal-700';
const mutedClass = 'text-[#5d6f64]';

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
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');

  useEffect(() => {
    setPassword('');
  }, [mode]);

  return (
    <form
      className="grid min-h-svh content-center gap-5 border-l border-emerald-950/10 bg-[#fbfdfb] px-7 py-10 sm:px-10 lg:px-14"
      onSubmit={(event) => {
        event.preventDefault();
        onSubmit({ email, password });
      }}
    >
      <div>
        <p className={eyebrowClass}>Carbide starter</p>
        <h1 className="m-0 text-[34px] leading-tight text-[#16211b]">
          {isRegister ? 'Create the first account' : 'Log in to the dashboard'}
        </h1>
        <p className={`mt-3 ${mutedClass}`}>
          React owns this interface. The Go backend owns auth, sessions, and Postgres state.
        </p>
      </div>

      {error ? <p className="m-0 bg-rose-50 px-3 py-2 text-rose-800">{error}</p> : null}

      <label className="grid gap-2 font-bold text-[#16211b]">
        Email
        <input
          className={inputClass}
          name="email"
          type="email"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          autoComplete="email"
          required
        />
      </label>

      <label className="grid gap-2 font-bold text-[#16211b]">
        Password
        <input
          className={inputClass}
          name="password"
          type="password"
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          autoComplete={isRegister ? 'new-password' : 'current-password'}
          required
        />
      </label>

      <button className={buttonClass} type="submit" disabled={busy}>
        {busy ? 'Working...' : isRegister ? 'Create account' : 'Log in'}
      </button>

      <p className={`m-0 ${mutedClass}`}>
        {isRegister ? 'Already registered?' : 'Need an account?'}{' '}
        <button
          className={linkButtonClass}
          type="button"
          onClick={() => onMode(isRegister ? 'login' : 'register')}
        >
          {isRegister ? 'Log in' : 'Create one'}
        </button>
      </p>
    </form>
  );
}

function Dashboard({ user, onLogout, busy }) {
  return (
    <main className="mx-auto max-w-6xl px-6 py-8 sm:px-10 lg:py-14">
      <header className="mb-10 flex flex-col gap-5 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <p className={eyebrowClass}>Bun frontend + Go API + Postgres</p>
          <h1 className="m-0 text-5xl leading-none text-[#16211b] sm:text-6xl">{APP_NAME}</h1>
        </div>
        <button className={buttonClass} type="button" onClick={onLogout} disabled={busy}>
          {busy ? 'Logging out...' : 'Log out'}
        </button>
      </header>

      <section
        className="mb-9 grid gap-px overflow-hidden border border-emerald-950/10 bg-emerald-950/10 md:grid-cols-3"
        aria-label="Application status"
      >
        {[
          ['Frontend', 'React + Bun container'],
          ['Backend', 'Go API container'],
          ['Database', 'Postgres container']
        ].map(([label, value]) => (
          <div className="bg-white p-6" key={label}>
            <span className="mb-1 block text-sm text-[#6b7e72]">{label}</span>
            <strong className="text-[#16211b]">{value}</strong>
          </div>
        ))}
      </section>

      <section className="max-w-3xl border border-emerald-950/10 bg-white p-6">
        <p className={eyebrowClass}>Session</p>
        <h2 className="m-0 text-3xl leading-tight text-[#16211b]">Logged in as {user.email}</h2>
        <p className={`mt-4 ${mutedClass}`}>
          The browser talks to <code className="bg-emerald-50 px-1.5 py-0.5">/api</code> on the
          same origin. Bun proxies those requests to the Go backend, and the backend persists the
          session in Postgres.
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

  const mode = useMemo(() => (route === '/login' ? 'login' : 'register'), [route]);

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
      <main className="grid min-h-svh place-items-center px-8 text-center">
        <div>
          <p className={eyebrowClass}>Carbide</p>
          <h1 className="m-0 text-4xl leading-tight text-[#16211b]">Loading app state</h1>
        </div>
      </main>
    );
  }

  if (route === '/dashboard' && user) {
    return <Dashboard user={user} onLogout={logout} busy={busy} />;
  }

  return (
    <main className="grid min-h-svh bg-[#f6f8f5] lg:grid-cols-[minmax(0,1fr)_minmax(360px,480px)]">
      <section className="grid min-h-[42svh] content-end bg-[linear-gradient(150deg,#0f766e_0%,#1b3f3a_48%,#16211b_100%)] px-8 py-10 text-white sm:px-12 lg:min-h-svh lg:px-[7vw] lg:py-[7vw]">
        <p className="mb-3 text-xs font-extrabold uppercase tracking-normal text-white/75">
          {APP_NAME}
        </p>
        <h1 className="m-0 max-w-4xl text-[clamp(42px,7vw,82px)] leading-none">
          Containerized full stack development with a Go API backend.
        </h1>
        <p className="mt-5 max-w-2xl text-lg text-white/80">
          Run one command. Get a React and Bun frontend, a Go API backend, Tailwind styling, and a
          Postgres database wired together with same-origin auth.
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
