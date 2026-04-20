import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/svelte';
import { http, HttpResponse } from 'msw';
import { server } from '../mocks/server.js';
import { auth } from '../lib/auth.svelte.js';
import AuthModal from './AuthModal.svelte';

beforeEach(() => {
  auth.user = null;
  auth.ready = false;
});

describe('AuthModal', () => {
  it('renders the login form by default', () => {
    render(AuthModal, { initialMode: 'login', onclose: () => {} });
    // h2 heading text is "Log In"
    expect(screen.getByRole('heading', { name: /log in/i })).toBeInTheDocument();
    expect(screen.getByPlaceholderText(/email/i)).toBeInTheDocument();
    // submit button text is "Log In" while not loading
    expect(screen.getByRole('button', { name: /^log in$/i })).toBeInTheDocument();
  });

  it('submits login and calls onclose on success', async () => {
    const onclose = vi.fn();
    render(AuthModal, { initialMode: 'login', onclose });
    await fireEvent.input(screen.getByPlaceholderText(/email/i), { target: { value: 'u@example.com' } });
    await fireEvent.input(screen.getByPlaceholderText(/password/i), { target: { value: 'hunter22' } });
    await fireEvent.submit(screen.getByRole('button', { name: /^log in$/i }).closest('form'));
    await vi.waitFor(() => expect(onclose).toHaveBeenCalled());
    expect(auth.user).toMatchObject({ id: 'u1' });
  });

  it('shows error message on login failure', async () => {
    server.use(
      http.post('/api/auth/login', () => HttpResponse.json({ error: 'nope' }, { status: 401 }))
    );
    render(AuthModal, { initialMode: 'login', onclose: () => {} });
    await fireEvent.input(screen.getByPlaceholderText(/email/i), { target: { value: 'u@example.com' } });
    await fireEvent.input(screen.getByPlaceholderText(/password/i), { target: { value: 'hunter22' } });
    await fireEvent.submit(screen.getByPlaceholderText(/email/i).closest('form'));
    expect(await screen.findByText('nope')).toBeInTheDocument();
  });

  it('switches to register mode and exposes the display name field', async () => {
    render(AuthModal, { initialMode: 'login', onclose: () => {} });
    // The switch link text is "Sign up" (lowercase 'up')
    await fireEvent.click(screen.getByRole('button', { name: /sign up/i }));
    expect(screen.getByPlaceholderText(/display name/i)).toBeInTheDocument();
  });
});
