# Welcome Modal — Design Spec

Date: 2026-04-15

## Overview

Show a welcome modal to first-time visitors of BeeByBike. "First-time" is determined by the absence of a session cookie: if `api.me()` fails and the app falls back to creating a new anonymous session, it's a new visitor.

## State change — `auth.svelte.js`

Add `isNewSession: false` to the shared `auth` state object. In `checkSession()`, set `auth.isNewSession = true` immediately before calling `api.anonymous()`. No other changes needed; the session cookie is the source of truth.

```js
export const auth = $state({ user: null, ready: false, isNewSession: false });

export async function checkSession() {
  try {
    auth.user = await api.me();
  } catch {
    try {
      auth.isNewSession = true;
      auth.user = await api.anonymous();
    } catch (e) { ... }
  } finally {
    auth.ready = true;
  }
}
```

## New component — `WelcomeModal.svelte`

Location: `frontend/src/components/WelcomeModal.svelte`

Follows the same overlay + centered modal structure as `AuthModal.svelte`.

**Content:**

- **Title**: "Welcome to BeeByBike"
- **Intro**: A bicycle routing app for Berlin that learns your preferences. Paint areas on the map to mark roads and neighbourhoods you love or want to avoid — then request a route that reflects them.
- **Steps** (numbered list):
  1. Use the brush tool to paint areas green (prefer) or red (avoid)
  2. Enter a start and destination in the search bar
  3. Get a bicycle route tailored to your preferences
- **Button**: "Start exploring" — dismisses the modal

No close button (×). The only exit is the CTA button.

## Wiring — `App.svelte`

Import `WelcomeModal`. Render it when `auth.ready && auth.isNewSession`. Dismissing sets `auth.isNewSession = false`.

```svelte
{#if auth.ready && auth.isNewSession}
  <WelcomeModal onclose={() => auth.isNewSession = false} />
{/if}
```

## What's not in scope

- Persisting dismissal to localStorage or the server — the session cookie alone determines first-visit status.
- A "Don't show again" checkbox — redundant given the session-based trigger.
- Any changes to backend or database.
