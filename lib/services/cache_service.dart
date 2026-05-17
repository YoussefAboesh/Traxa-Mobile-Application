// lib/services/cache_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static const String _cacheStudentsKey = 'cached_students';
  static const String _cacheDoctorsKey = 'cached_doctors';
  static const String _cacheSubjectsKey = 'cached_subjects';
  static const String _cacheLecturesKey = 'cached_lectures';
  static const String _cacheTimestampKey = 'cache_timestamp';
  static const Duration _cacheMaxAge = Duration(hours: 1);

  static Future<void> saveAllData({
    required List<dynamic> students,
    required List<dynamic> doctors,
    required List<dynamic> subjects,
    required List<dynamic> lectures,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheStudentsKey, jsonEncode(students));
    await prefs.setString(_cacheDoctorsKey, jsonEncode(doctors));
    await prefs.setString(_cacheSubjectsKey, jsonEncode(subjects));
    await prefs.setString(_cacheLecturesKey, jsonEncode(lectures));
    await prefs.setString(_cacheTimestampKey, DateTime.now().toIso8601String());
    if (kDebugMode) debugPrint('💾 Data cached successfully');
  }

  /// Loads the cached snapshot.
  ///
  /// When [ignoreExpiry] is false (default) a snapshot older than
  /// [_cacheMaxAge] is treated as stale and `null` is returned. Pass
  /// `ignoreExpiry: true` for the offline fallback, where showing stale
  /// data is better than showing nothing.
  static Future<Map<String, List<dynamic>>?> loadAllData(
      {bool ignoreExpiry = false}) async {
    final prefs = await SharedPreferences.getInstance();

    final timestampStr = prefs.getString(_cacheTimestampKey);
    if (!ignoreExpiry && timestampStr != null) {
      final timestamp = DateTime.parse(timestampStr);
      if (DateTime.now().difference(timestamp) > _cacheMaxAge) {
        if (kDebugMode) debugPrint('📦 Cache expired');
        return null;
      }
    }

    final studentsStr = prefs.getString(_cacheStudentsKey);
    final doctorsStr = prefs.getString(_cacheDoctorsKey);
    final subjectsStr = prefs.getString(_cacheSubjectsKey);
    final lecturesStr = prefs.getString(_cacheLecturesKey);

    if (studentsStr != null &&
        doctorsStr != null &&
        subjectsStr != null &&
        lecturesStr != null) {
      return {
        'students': jsonDecode(studentsStr) as List<dynamic>,
        'doctors': jsonDecode(doctorsStr) as List<dynamic>,
        'subjects': jsonDecode(subjectsStr) as List<dynamic>,
        'lectures': jsonDecode(lecturesStr) as List<dynamic>,
      };
    }

    return null;
  }

  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheStudentsKey);
    await prefs.remove(_cacheDoctorsKey);
    await prefs.remove(_cacheSubjectsKey);
    await prefs.remove(_cacheLecturesKey);
    await prefs.remove(_cacheTimestampKey);
    if (kDebugMode) debugPrint('🗑️ Cache cleared');
  }
}
