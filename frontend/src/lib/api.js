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
    const error = new Error(err.error || resp.statusText);
    error.status = resp.status;
    throw error;
  }
  if (resp.status === 204) return null;
  return resp.json();
}

export const api = {
  register: (email, password, display_name) =>
    request('POST', '/api/auth/register', { email, password, display_name }),
  anonymous: () => request('POST', '/api/auth/anonymous'),
  login: (email, password) =>
    request('POST', '/api/auth/login', { email, password }),
  logout: () => request('POST', '/api/auth/logout'),
  me: () => request('GET', '/api/auth/me'),
  getHomeLocation: () => request('GET', '/api/locations/home'),
  saveHomeLocation: (location) => request('PUT', '/api/locations/home', location),
  deleteHomeLocation: () => request('DELETE', '/api/locations/home'),
  getOverlay: (bbox) => request('GET', `/api/ratings?bbox=${bbox}`),
  paint: (geometry, value) => request('PUT', '/api/ratings/paint', { geometry, value }),
  route: (origin, destination, rating_weight, distance_influence) =>
    request('POST', '/api/route', {
      origin,
      destination,
      rating_weight,
      distance_influence,
    }),
  geocode: (q) => request('GET', `/api/geocode?q=${encodeURIComponent(q)}`),
};
