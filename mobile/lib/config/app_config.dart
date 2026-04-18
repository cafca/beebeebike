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
        defaultValue: 'http://127.0.0.1:3000',
      ),
      tileStyleUrl: String.fromEnvironment(
        'BEEBEEBIKE_TILE_STYLE_URL',
        defaultValue: 'http://127.0.0.1:8080/assets/styles/colorful/style.json',
      ),
    );
  }
}
