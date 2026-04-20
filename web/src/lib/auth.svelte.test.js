import { describe, it, expect, beforeEach } from 'vitest';
import { http, HttpResponse } from 'msw';
import { server } from '../mocks/server.js';
import { auth, checkSession, login, register, logout } from './auth.svelte.js';

beforeEach(() => {
  auth.user = null;
  auth.ready = false;
  auth.isNewSession = false;
});

describe('auth store', () => {
  it('checkSession uses the existing session when /me succeeds', async () => {
    await checkSession();
    expect(auth.user).toEqual({
      id: 'u1', email: 'u@example.com', display_name: 'U', anonymous: false,
    });
    expect(auth.ready).toBe(true);
    expect(auth.isNewSession).toBe(false);
  });

  it('checkSession falls back to anonymous when /me 401s', async () => {
    server.use(
      http.get('/api/auth/me', () => HttpResponse.json({ error: 'no session' }, { status: 401 }))
    );
    await checkSession();
    expect(auth.isNewSession).toBe(true);
    expect(auth.user).toMatchObject({ anonymous: true });
    expect(auth.ready).toBe(true);
  });

  it('checkSession sets user=null when both /me and /anonymous fail', async () => {
    server.use(
      http.get('/api/auth/me', () => HttpResponse.json({ error: 'no' }, { status: 401 })),
      http.post('/api/auth/anonymous', () => HttpResponse.json({ error: 'boom' }, { status: 500 }))
    );
    await checkSession();
    expect(auth.user).toBeNull();
    expect(auth.ready).toBe(true);
  });

  it('login sets user and ready', async () => {
    await login('u@example.com', 'hunter22');
    expect(auth.user).toMatchObject({ id: 'u1', email: 'u@example.com' });
    expect(auth.ready).toBe(true);
  });

  it('register sets user and ready', async () => {
    await register('new@example.com', 'hunter22', 'New');
    expect(auth.user).toMatchObject({ id: 'u2', display_name: 'New' });
    expect(auth.ready).toBe(true);
  });

  it('logout swaps user for a fresh anonymous identity', async () => {
    auth.user = { id: 'u1', anonymous: false };
    await logout();
    expect(auth.user).toMatchObject({ id: 'anon1', anonymous: true });
    expect(auth.ready).toBe(true);
  });
});
