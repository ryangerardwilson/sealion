import appShell from '../index.html';

const port = Number(Bun.env.FRONTEND_PORT || Bun.env.PORT || 8080);
const backendUrl = Bun.env.BACKEND_URL || 'http://backend:8080';
const publicUrl = Bun.env.PUBLIC_URL || '';
const backendOrigin = new URL(backendUrl);

function proxyToBackend(request) {
  const incomingUrl = new URL(request.url);
  const upstreamUrl = new URL(`${incomingUrl.pathname}${incomingUrl.search}`, backendOrigin);
  const headers = new Headers(request.headers);
  headers.delete('host');
  headers.set('x-forwarded-host', incomingUrl.host);
  headers.set('x-forwarded-proto', incomingUrl.protocol.replace(':', ''));

  const options = {
    method: request.method,
    headers,
    redirect: 'manual'
  };

  if (request.method !== 'GET' && request.method !== 'HEAD') {
    options.body = request.body;
  }

  return fetch(upstreamUrl, options);
}

const server = Bun.serve({
  port,
  development: Bun.env.NODE_ENV !== 'production',
  routes: {
    '/': appShell,
    '/login': appShell,
    '/register': appShell,
    '/dashboard': appShell,
    '/api/*': proxyToBackend,
    '/health': proxyToBackend
  },
  fetch(request) {
    const url = new URL(request.url);
    if (url.pathname === '/api' || url.pathname.startsWith('/api/')) {
      return proxyToBackend(request);
    }
    if (url.pathname === '/health') {
      return proxyToBackend(request);
    }
    return new Response('Not found', {
      status: 404,
      headers: { 'Content-Type': 'text/plain; charset=utf-8' }
    });
  }
});

console.log(`Carbide Bun frontend listening inside container on :${server.port}`);
if (publicUrl) {
  console.log(`browser entrypoint ${publicUrl}`);
}
console.log(`proxying /api and /health to backend service ${backendUrl}`);
