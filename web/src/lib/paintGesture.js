let suppressClickUntil = 0;

export function suppressNextMapClick() {
  suppressClickUntil = Date.now() + 250;
}

export function shouldSuppressMapClick() {
  return Date.now() < suppressClickUntil;
}
