/// Global application constants and desktop configuration limits.
class AppConstants {
  // Prevent instantiation
  const AppConstants._();

  /// Official NVIDIA NIM OpenAI-compatible API base endpoint.
  static const String nvidiaBaseUrl = 'https://integrate.api.nvidia.com/v1';

  /// Secure storage key for persisting the user's NVIDIA API key locally.
  static const String secureStorageApiKey = 'nvidia_nim_api_key';

  /// Shared preference key for the selected default model.
  static const String prefDefaultModel = 'selected_default_model';

  /// Shared preference key for application theme mode.
  static const String prefThemeMode = 'app_theme_mode';

  /// Fallback default model identifier when dynamic fetch hasn't completed yet.
  static const String defaultModelId = 'meta/llama-3.2-11b-vision-instruct';

  /// Desktop window initial and minimum sizing dimensions.
  static const double windowMinWidth = 960.0;
  static const double windowMinHeight = 640.0;
  static const double windowDefaultWidth = 1280.0;
  static const double windowDefaultHeight = 820.0;

  /// Default application window title.
  static const String appTitle = 'NVIDIA AI Desktop';
}
