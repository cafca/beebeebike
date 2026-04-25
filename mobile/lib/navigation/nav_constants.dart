/// Tuning constants shared between the navigation overlay widgets and
/// the map-screen state machine. Kept in one place so a future sheet /
/// layout change doesn't silently overlap the recenter FAB.
library;

/// Approximate rendered height of the ETA bottom sheet. Used to offset the
/// RecenterFab so it never overlaps the sheet.
const double kEtaSheetHeight = 120;

/// Zoom used when flying the camera to the destination on arrival. Matches
/// the nav-camera design spec (Q4).
const double kArrivalZoom = 17;
