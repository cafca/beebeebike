const RATING_WEIGHT_STORAGE_KEY = 'beebeebike.ratingWeight';
const DISTANCE_INFLUENCE_STORAGE_KEY = 'beebeebike.distanceInfluence';
const DEFAULT_RATING_WEIGHT = 0.5;
const DEFAULT_DISTANCE_INFLUENCE = 60;

function clampRatingWeight(value) {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) return DEFAULT_RATING_WEIGHT;
  return Math.min(1, Math.max(0, numeric));
}

function clampDistanceInfluence(value) {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) return DEFAULT_DISTANCE_INFLUENCE;
  return Math.min(100, Math.max(0, numeric));
}

function initialRatingWeight() {
  if (typeof window === 'undefined') return DEFAULT_RATING_WEIGHT;
  return clampRatingWeight(window.localStorage.getItem(RATING_WEIGHT_STORAGE_KEY) ?? DEFAULT_RATING_WEIGHT);
}

function initialDistanceInfluence() {
  if (typeof window === 'undefined') return DEFAULT_DISTANCE_INFLUENCE;
  return clampDistanceInfluence(
    window.localStorage.getItem(DISTANCE_INFLUENCE_STORAGE_KEY) ?? DEFAULT_DISTANCE_INFLUENCE
  );
}

export const preferences = $state({
  ratingWeight: initialRatingWeight(),
  distanceInfluence: initialDistanceInfluence(),
});

export function setRatingWeight(value) {
  preferences.ratingWeight = clampRatingWeight(value);
  if (typeof window !== 'undefined') {
    window.localStorage.setItem(RATING_WEIGHT_STORAGE_KEY, String(preferences.ratingWeight));
  }
}

export function setDistanceInfluence(value) {
  preferences.distanceInfluence = clampDistanceInfluence(value);
  if (typeof window !== 'undefined') {
    window.localStorage.setItem(
      DISTANCE_INFLUENCE_STORAGE_KEY,
      String(preferences.distanceInfluence)
    );
  }
}

export function formatRatingWeight(value) {
  return `${Math.round(clampRatingWeight(value) * 100)}%`;
}

export function formatDistanceInfluence(value) {
  return String(Math.round(clampDistanceInfluence(value)));
}
