import { api } from './api.js';

// Shared reactive state — wrapped in object so property mutation is valid
export const auth = $state({ user: null });

export async function checkSession() {
  try {
    auth.user = await api.me();
  } catch {
    auth.user = null;
  }
}

export async function login(email, password) {
  auth.user = await api.login(email, password);
}

export async function register(email, password, displayName) {
  auth.user = await api.register(email, password, displayName);
}

export async function logout() {
  await api.logout();
  auth.user = null;
}
