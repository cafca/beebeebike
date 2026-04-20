import { http, HttpResponse } from 'msw';

// Default handlers return 200 with realistic shapes. Override per test with server.use().
export const handlers = [
  http.get('/api/auth/me', () =>
    HttpResponse.json({ id: 'u1', email: 'u@example.com', display_name: 'U', anonymous: false })
  ),
  http.post('/api/auth/anonymous', () =>
    HttpResponse.json({ id: 'anon1', email: null, display_name: null, anonymous: true })
  ),
  http.post('/api/auth/login', () =>
    HttpResponse.json({ id: 'u1', email: 'u@example.com', display_name: 'U', anonymous: false })
  ),
  http.post('/api/auth/register', () =>
    HttpResponse.json({ id: 'u2', email: 'new@example.com', display_name: 'New', anonymous: false })
  ),
  http.post('/api/auth/logout', () => new HttpResponse(null, { status: 204 })),

  http.get('/api/locations/home', () => HttpResponse.json({ label: 'Home', lng: 13.4, lat: 52.5 })),
  http.put('/api/locations/home', async ({ request }) => HttpResponse.json(await request.json())),
  http.delete('/api/locations/home', () => new HttpResponse(null, { status: 204 })),

  http.get('/api/ratings', () =>
    HttpResponse.json({ type: 'FeatureCollection', features: [], can_undo: false, can_redo: false })
  ),
  http.put('/api/ratings/paint', () => HttpResponse.json({ can_undo: true, can_redo: false })),
  http.post('/api/ratings/undo', () => HttpResponse.json({ can_undo: false, can_redo: true })),
  http.post('/api/ratings/redo', () => HttpResponse.json({ can_undo: true, can_redo: false })),

  http.post('/api/route', () =>
    HttpResponse.json({
      geometry: { type: 'LineString', coordinates: [[13.4, 52.5], [13.41, 52.51]] },
      distance: 1200,
      time: 360,
    })
  ),

  http.get('/api/geocode', () =>
    HttpResponse.json({
      features: [
        {
          geometry: { coordinates: [13.4, 52.5] },
          properties: { name: 'Alexanderplatz', osm_key: 'place', osm_value: 'square' },
        },
      ],
    })
  ),
];
