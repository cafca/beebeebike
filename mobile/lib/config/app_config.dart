class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.tileServerBaseUrl,
    required this.tileStyleUrl,
    required this.ratingsSseEnabled,
    this.privacyPolicyUrl = 'https://beebeebike.com/datenschutz/',
  });

  final String apiBaseUrl;
  final String tileServerBaseUrl;
  final String privacyPolicyUrl;

  /// Test-only: a remote style URL passed straight to `MapLibreMap.styleString`.
  /// Production uses `mapStyleProvider`, which loads the bundled style and
  /// substitutes [tileServerBaseUrl].
  final String tileStyleUrl;

  /// Client-side kill switch for the rating-change SSE stream. When false,
  /// `RatingEventsClient` is never started and the overlay relies purely on
  /// camera-idle polling. Pair with the backend `BEEBEEBIKE_RATINGS_SSE_ENABLED`
  /// env when disabling globally — either flag off is enough to stop the
  /// push traffic.
  final bool ratingsSseEnabled;

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      apiBaseUrl: String.fromEnvironment(
        'BEEBEEBIKE_API_BASE_URL',
        defaultValue: 'http://127.0.0.1:3000',
      ),
      tileServerBaseUrl: String.fromEnvironment(
        'BEEBEEBIKE_TILE_SERVER_BASE_URL',
        defaultValue: 'http://127.0.0.1:8080',
      ),
      tileStyleUrl: String.fromEnvironment(
        'BEEBEEBIKE_TILE_STYLE_URL',
        defaultValue: 'http://127.0.0.1:8080/assets/styles/colorful/style.json',
      ),
      ratingsSseEnabled: bool.fromEnvironment(
        'BEEBEEBIKE_RATINGS_SSE_ENABLED',
        defaultValue: true,
      ),
      privacyPolicyUrl: String.fromEnvironment(
        'BEEBEEBIKE_PRIVACY_POLICY_URL',
        defaultValue: 'https://beebeebike.com/datenschutz/',
      ),
    );
  }
}
