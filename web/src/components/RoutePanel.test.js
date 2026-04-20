import { describe, it, expect, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/svelte';
import { route } from '../lib/routing.svelte.js';
import RoutePanel from './RoutePanel.svelte';

beforeEach(() => {
  route.loading = false;
  route.data = null;
  route.origin = null;
  route.destination = null;
});

describe('RoutePanel', () => {
  it('renders nothing when there is no route and not loading', () => {
    const { container } = render(RoutePanel);
    // Component only renders .route-panel when loading or data is set
    expect(container.querySelector('.route-panel')).not.toBeInTheDocument();
  });

  it('shows computing message when route.loading is true', () => {
    route.loading = true;
    render(RoutePanel);
    expect(screen.getByText(/computing route/i)).toBeInTheDocument();
  });

  it('shows formatted distance and time for a short route', () => {
    route.data = { distance: 2500, time: 600000 };
    render(RoutePanel);
    // formatDist(2500) = "2.5 km", formatTime(600000) = "10 min"
    expect(screen.getByText('2.5 km')).toBeInTheDocument();
    expect(screen.getByText('10 min')).toBeInTheDocument();
  });

  it('shows formatted distance and time for a longer route with hours', () => {
    route.data = { distance: 450, time: 3900000 };
    render(RoutePanel);
    // formatDist(450) = "450 m", formatTime(3900000) = "1h 5m" (3900000ms / 60000 = 65 min)
    expect(screen.getByText('450 m')).toBeInTheDocument();
    expect(screen.getByText('1h 5m')).toBeInTheDocument();
  });
});
