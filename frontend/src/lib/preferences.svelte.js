const STORAGE_KEY = 'beebeebike.ratingWeight';
const DEFAULT_RATING_WEIGHT = 1;

function clampRatingWeight(value) {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) return DEFAULT_RATING_WEIGHT;
  return Math.min(1, Math.max(0, numeric));
}

function initialRatingWeight() {
  if (typeof window === 'undefined') return DEFAULT_RATING_WEIGHT;
  return clampRatingWeight(window.localStorage.getItem(STORAGE_KEY) ?? DEFAULT_RATING_WEIGHT);
}

export const preferences = $state({
  ratingWeight: initialRatingWeight(),
});

export function setRatingWeight(value) {
  preferences.ratingWeight = clampRatingWeight(value);
  if (typeof window !== 'undefined') {
    window.localStorage.setItem(STORAGE_KEY, String(preferences.ratingWeight));
  }
}

export function formatRatingWeight(value) {
  return `${Math.round(clampRatingWeight(value) * 100)}%`;
}
