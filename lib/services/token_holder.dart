import 'package:flutter/foundation.dart';
import 'secure_storage_service.dart';

/// In-memory auth token backed by secure storage. Exposed as a
/// [ValueListenable] so HTTP interceptors / badges can react without
/// polling.
class TokenHolder {
  final ValueNotifier<String?> _token = ValueNotifier<String?>(null);

  ValueListenable<String?> get listenable => _token;

  String? get current => _token.value;
  bool get hasToken => _token.value != null && _token.value!.isNotEmpty;

  Future<String?> load() async {
    final saved = await SecureStorageService.getToken();
    _token.value = saved;
    return saved;
  }

  Future<void> set(String? token) async {
    _token.value = token;
    if (token == null || token.isEmpty) {
      await SecureStorageService.deleteToken();
    } else {
      await SecureStorageService.saveToken(token);
    }
  }

  Future<void> clear() => set(null);

  Map<String, String> get authHeader =>
      hasToken ? {'Authorization': 'Bearer ${_token.value!}'} : const {};
}
