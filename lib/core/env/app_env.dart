import 'app_flavor.dart';
import 'server_config.dart';

/// Pick at startup with: flutter run --dart-define=FLAVOR=dev|prod
class AppEnv {
  AppEnv._();

  // Default to prod so a plain `flutter run` ships production config.
  static final AppFlavor flavor = parseFlavor(
    const String.fromEnvironment('FLAVOR', defaultValue: 'prod'),
  );

  /// Resolved at every call so changing the server URL from the login screen
  /// takes effect immediately without an app restart.
  static String get baseUrl => ServerConfig.currentUrl;

  static String get wsUrl => baseUrl
      .replaceFirst('https://', 'wss://')
      .replaceFirst('http://', 'ws://');

  static bool get isDev => flavor == AppFlavor.dev;
  static bool get isNonProd => flavor != AppFlavor.prod;
}
