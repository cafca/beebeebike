async function request(method, path, body) {
  const opts = {
    method,
    headers: { 'Content-Type': 'application/json' },
    credentials: 'same-origin',
  };
  if (body) opts.body = JSON.stringify(body);
  const resp = await fetch(path, opts);
  if (!resp.ok) {
    const err = await resp.json().catch(() => ({ error: resp.statusText }));
    throw new Error(err.error || resp.statusText);
  }
  return resp.json();
}

export const api = {
  register: (email, password, display_name) =>
    request('POST', '/api/auth/register', { email, password, display_name }),
  login: (email, password) =>
    request('POST', '/api/auth/login', { email, password }),
  logout: () => request('POST', '/api/auth/logout'),
  me: () => request('GET', '/api/auth/me'),
  getOverlay: (bbox) => request('GET', `/api/ratings?bbox=${bbox}`),
  paint: (geometry, value) => request('PUT', '/api/ratings/paint', { geometry, value }),
  route: (origin, destination) =>
    request('POST', '/api/route', { origin, destination }),
  geocode: (q) => request('GET', `/api/geocode?q=${encodeURIComponent(q)}`),
};
