import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';
import { server } from '../mocks/server.js';
import { api } from './api.js';

describe('api', () => {
  it('login posts JSON and returns the user', async () => {
    let captured;
    server.use(
      http.post('/api/auth/login', async ({ request }) => {
        captured = await request.json();
        return HttpResponse.json({ id: 'u1', email: captured.email });
      })
    );
    const user = await api.login('a@b.c', 'hunter22');
    expect(captured).toEqual({ email: 'a@b.c', password: 'hunter22' });
    expect(user).toEqual({ id: 'u1', email: 'a@b.c' });
  });

  it('register posts display_name', async () => {
    let captured;
    server.use(
      http.post('/api/auth/register', async ({ request }) => {
        captured = await request.json();
        return HttpResponse.json({ id: 'u2' });
      })
    );
    await api.register('x@y.z', 'password8', 'Sam');
    expect(captured).toEqual({ email: 'x@y.z', password: 'password8', display_name: 'Sam' });
  });

  it('logout returns null on 204', async () => {
    expect(await api.logout()).toBeNull();
  });

  it('getOverlay passes bbox in querystring', async () => {
    let url;
    server.use(
      http.get('/api/ratings', ({ request }) => {
        url = new URL(request.url);
        return HttpResponse.json({ type: 'FeatureCollection', features: [] });
      })
    );
    await api.getOverlay('1,2,3,4');
    expect(url.searchParams.get('bbox')).toBe('1,2,3,4');
  });

  it('paint includes target_id when provided, omits when null', async () => {
    const bodies = [];
    server.use(
      http.put('/api/ratings/paint', async ({ request }) => {
        bodies.push(await request.json());
        return HttpResponse.json({ can_undo: true, can_redo: false });
      })
    );
    const geom = { type: 'Polygon', coordinates: [] };
    await api.paint(geom, 3);
    await api.paint(geom, -7, 42);
    expect(bodies[0]).toEqual({ geometry: geom, value: 3 });
    expect(bodies[1]).toEqual({ geometry: geom, value: -7, target_id: 42 });
  });

  it('route posts origin/destination + tuning', async () => {
    let captured;
    server.use(
      http.post('/api/route', async ({ request }) => {
        captured = await request.json();
        return HttpResponse.json({ geometry: {}, distance: 0, time: 0 });
      })
    );
    await api.route([1, 2], [3, 4], 0.5, 70);
    expect(captured).toEqual({
      origin: [1, 2],
      destination: [3, 4],
      rating_weight: 0.5,
      distance_influence: 70,
    });
  });

  it('geocode URL-encodes the query', async () => {
    let url;
    server.use(
      http.get('/api/geocode', ({ request }) => {
        url = new URL(request.url);
        return HttpResponse.json({ features: [] });
      })
    );
    await api.geocode('hello world & friends');
    expect(url.searchParams.get('q')).toBe('hello world & friends');
  });

  it('throws with status and error message on non-2xx JSON', async () => {
    server.use(
      http.post('/api/auth/login', () =>
        HttpResponse.json({ error: 'bad creds' }, { status: 401 })
      )
    );
    await expect(api.login('a', 'b')).rejects.toMatchObject({
      message: 'bad creds',
      status: 401,
    });
  });

  it('throws with statusText on non-JSON error', async () => {
    server.use(
      http.post('/api/auth/login', () => new HttpResponse('oops', { status: 500 }))
    );
    await expect(api.login('a', 'b')).rejects.toMatchObject({ status: 500 });
  });
});
