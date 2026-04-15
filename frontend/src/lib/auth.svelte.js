import { api } from './api.js';

// Shared reactive state, wrapped in an object so property mutation is valid.
export const auth = $state({ user: null, ready: false });

export async function checkSession() {
  try {
    auth.user = await api.me();
  } catch {
    try {
      auth.user = await api.anonymous();
    } catch (e) {
      console.error('Failed to start anonymous session:', e);
      auth.user = null;
    }
  } finally {
    auth.ready = true;
  }
}

export async function login(email, password) {
  auth.user = await api.login(email, password);
  auth.ready = true;
}

export async function register(email, password, displayName) {
  auth.user = await api.register(email, password, displayName);
  auth.ready = true;
}

export async function logout() {
  await api.logout();
  auth.user = await api.anonymous();
  auth.ready = true;
}
