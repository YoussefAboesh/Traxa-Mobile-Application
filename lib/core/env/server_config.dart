import 'package:shared_preferences/shared_preferences.dart';
import '../constants/storage_keys.dart';


class ServerConfig {
  ServerConfig._();

  static String? _override;
  static bool _loaded = false;

  /// Compile-time fallback used only until the user sets a URL.
  static const String compileTimeDefault = String.fromEnvironment(
    'PROD_URL',
    defaultValue: 'https://traxa-system.online',
  );

  /// Must be awaited before first [currentUrl] read (call from main()).
  static Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(StorageKeys.serverBaseUrl);
    if (saved != null && saved.trim().isNotEmpty) {
      _override = _normalize(saved);
    }
    _loaded = true;
  }

  static String get currentUrl => _override ?? compileTimeDefault;

  static bool get hasUserOverride => _override != null;

  static Future<void> setUrl(String raw) async {
    final normalized = _normalize(raw);
    _override = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.serverBaseUrl, normalized);
  }

  static Future<void> clear() async {
    _override = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.serverBaseUrl);
  }

  /// Trim, drop trailing slash, prepend https:// if no scheme.
  static String _normalize(String raw) {
    var s = raw.trim();
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'https://$s';
    }
    return s;
  }

  /// Validate that the user-entered string parses as an http(s) URL with a host.
  static String? validate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return 'Please enter a server URL';
    final normalized = _normalize(s);
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.host.isEmpty) return 'Invalid URL';
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return 'URL must start with http:// or https://';
    }
    return null;
  }
}
