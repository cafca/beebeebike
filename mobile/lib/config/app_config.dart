class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.tileStyleUrl,
  });

  final String apiBaseUrl;
  final String tileStyleUrl;

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      apiBaseUrl: String.fromEnvironment(
        'BEEBEEBIKE_API_BASE_URL',
        defaultValue: 'https://maps.001.land',
      ),
      tileStyleUrl: String.fromEnvironment(
        'BEEBEEBIKE_TILE_STYLE_URL',
        defaultValue: 'https://maps.001.land/tiles/assets/styles/colorful/style.json',
      ),
    );
  }
}
