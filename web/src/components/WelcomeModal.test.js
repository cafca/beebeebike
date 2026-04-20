import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/svelte';
import WelcomeModal from './WelcomeModal.svelte';

describe('WelcomeModal', () => {
  it('renders the welcome heading and CTA button', () => {
    render(WelcomeModal, { onclose: () => {} });
    // Actual heading text: "Welcome to BeeBeeBike"
    expect(screen.getByRole('heading', { name: /welcome to beebeebike/i })).toBeInTheDocument();
    // Actual button text: "Start exploring"
    expect(screen.getByRole('button', { name: /start exploring/i })).toBeInTheDocument();
  });

  it('calls onclose when the CTA button is clicked', async () => {
    const onclose = vi.fn();
    render(WelcomeModal, { onclose });
    await fireEvent.click(screen.getByRole('button', { name: /start exploring/i }));
    expect(onclose).toHaveBeenCalledOnce();
  });
});
