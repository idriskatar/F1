import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps the personal RapidAPI key in the device's encrypted secure storage.
class RapidApiKeyStore {
  RapidApiKeyStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();
  static const _storageKey = 'rapidapi_f1_live_pulse_key';
  final FlutterSecureStorage _storage;

  Future<String?> read() => _storage.read(key: _storageKey);
  Future<void> save(String value) => _storage.write(key: _storageKey, value: value.trim());
  Future<void> delete() => _storage.delete(key: _storageKey);
}
