import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocationSnapshot {
  final double latitude;
  final double longitude;
  final String source;
  final String? permissionStatus;
  final String? areaLabel;
  final String? locality;
  final String? administrativeArea;
  final String? cityName;
  final String? districtName;
  final String? neighborhoodName;
  final double? accuracyMeters;
  final DateTime capturedAt;

  const AppLocationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.source,
    required this.capturedAt,
    this.permissionStatus,
    this.areaLabel,
    this.locality,
    this.administrativeArea,
    this.cityName,
    this.districtName,
    this.neighborhoodName,
    this.accuracyMeters,
  });

  String? get normalizedCityName =>
      _normalizeCityName(cityName ?? administrativeArea ?? locality);

  String? get normalizedDistrictName => _normalizeDistrictName(
    districtName ?? (_looksLikeDistrict(locality) ? locality : null),
  );

  String? get normalizedNeighborhoodName =>
      _normalizeNeighborhoodName(neighborhoodName ?? areaLabel);

  String? get compactRegionLabel {
    final city = normalizedCityName;
    final district = normalizedDistrictName;
    final neighborhood = normalizedNeighborhoodName;

    final primary = [
      if (district != null && district.isNotEmpty) district,
      if (neighborhood != null && neighborhood.isNotEmpty) neighborhood,
    ].join(' ');

    if (primary.isNotEmpty && city != null && city.isNotEmpty) {
      return '$primary, $city';
    }
    if (primary.isNotEmpty) {
      return primary;
    }
    if (city != null && city.isNotEmpty) {
      return city;
    }
    return null;
  }

  String? get customerFacingRegionLabel {
    final city = normalizedCityName;
    final district = normalizedDistrictName;
    final neighborhood = normalizedNeighborhoodName;

    final primary = neighborhood ?? district;
    if (primary != null &&
        primary.isNotEmpty &&
        city != null &&
        city.isNotEmpty) {
      return '$primary, $city';
    }
    if (primary != null && primary.isNotEmpty) {
      return primary;
    }
    if (city != null && city.isNotEmpty) {
      return city;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'source': source,
    'permissionStatus': permissionStatus,
    'areaLabel': areaLabel,
    'locality': locality,
    'administrativeArea': administrativeArea,
    'cityName': cityName,
    'districtName': districtName,
    'neighborhoodName': neighborhoodName,
    'accuracyMeters': accuracyMeters,
    'capturedAt': capturedAt.toIso8601String(),
  };

  static AppLocationSnapshot? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();
    final capturedAt = DateTime.tryParse((json['capturedAt'] ?? '') as String);
    if (latitude == null || longitude == null || capturedAt == null) {
      return null;
    }
    return AppLocationSnapshot(
      latitude: latitude,
      longitude: longitude,
      source: ((json['source'] as String?) ?? 'unknown').trim(),
      capturedAt: capturedAt,
      permissionStatus: (json['permissionStatus'] as String?)?.trim(),
      areaLabel: (json['areaLabel'] as String?)?.trim(),
      locality: (json['locality'] as String?)?.trim(),
      administrativeArea: (json['administrativeArea'] as String?)?.trim(),
      cityName: (json['cityName'] as String?)?.trim(),
      districtName: (json['districtName'] as String?)?.trim(),
      neighborhoodName: (json['neighborhoodName'] as String?)?.trim(),
      accuracyMeters: (json['accuracyMeters'] as num?)?.toDouble(),
    );
  }
}

class AppLocationService {
  AppLocationService._();

  static final AppLocationService instance = AppLocationService._();
  static const _snapshotKey = 'cartly_app_location_snapshot_v1';
  static const _historyKey = 'cartly_app_location_history_v1';
  static const _maxHistoryCount = 6;
  final ValueNotifier<AppLocationSnapshot?> snapshot = ValueNotifier(null);
  final ValueNotifier<List<AppLocationSnapshot>> history = ValueNotifier(
    const <AppLocationSnapshot>[],
  );

  bool _initializing = false;
  Future<void>? _activeRefresh;

  Future<void> initializeOnLaunch() async {
    if (_initializing) return;
    _initializing = true;
    try {
      await _loadCached();
      await _refresh(
        requestPermissionIfNeeded: true,
        force: false,
        source: 'app_launch',
      );
    } finally {
      _initializing = false;
    }
  }

  Future<void> refreshIfAuthorized() async {
    await _refresh(
      requestPermissionIfNeeded: false,
      force: false,
      source: 'app_resume',
    );
  }

  Future<void> refreshForScanStart() async {
    await _refresh(
      requestPermissionIfNeeded: false,
      force: true,
      source: 'scan_start',
    );
  }

  Future<AppLocationSnapshot?> refreshForUserAction() async {
    await _refresh(
      requestPermissionIfNeeded: true,
      force: true,
      source: 'manual_refresh',
    );
    return snapshot.value;
  }

  Future<void> _loadCached() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = (sp.getString(_snapshotKey) ?? '').trim();
      if (raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          snapshot.value = AppLocationSnapshot.fromJson(decoded);
        }
      }

      final historyRaw = (sp.getString(_historyKey) ?? '').trim();
      if (historyRaw.isEmpty) {
        if (snapshot.value != null) {
          history.value = [snapshot.value!];
        }
        return;
      }

      final historyDecoded = jsonDecode(historyRaw);
      if (historyDecoded is! List) return;
      final loaded = historyDecoded
          .whereType<Map<String, dynamic>>()
          .map(AppLocationSnapshot.fromJson)
          .whereType<AppLocationSnapshot>()
          .toList(growable: false);
      if (loaded.isNotEmpty) {
        history.value = loaded;
      } else if (snapshot.value != null) {
        history.value = [snapshot.value!];
      }
    } catch (_) {}
  }

  Future<void> _refresh({
    required bool requestPermissionIfNeeded,
    required bool force,
    required String source,
  }) async {
    if (_activeRefresh != null) {
      await _activeRefresh;
      return;
    }

    final task = _performRefresh(
      requestPermissionIfNeeded: requestPermissionIfNeeded,
      force: force,
      source: source,
    );
    _activeRefresh = task;
    try {
      await task;
    } finally {
      _activeRefresh = null;
    }
  }

  Future<void> _performRefresh({
    required bool requestPermissionIfNeeded,
    required bool force,
    required String source,
  }) async {
    try {
      final current = snapshot.value;
      if (!force &&
          current != null &&
          DateTime.now().difference(current.capturedAt) <
              const Duration(hours: 6)) {
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied &&
          requestPermissionIfNeeded) {
        permission = await Geolocator.requestPermission();
      }

      if (!_canUse(permission)) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(const Duration(seconds: 5));

      Placemark? placemark;
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(const Duration(seconds: 5));
        if (placemarks.isNotEmpty) {
          placemark = placemarks.first;
        }
      } catch (_) {}

      final rawCity = _firstNonEmpty([
        placemark?.locality,
        placemark?.administrativeArea,
      ]);
      final rawDistrict = placemark?.subAdministrativeArea?.trim();
      final rawNeighborhood = _firstNonEmpty([
        placemark?.subLocality,
        placemark?.thoroughfare,
      ]);

      final next = AppLocationSnapshot(
        latitude: position.latitude,
        longitude: position.longitude,
        source: source,
        permissionStatus: permission.name,
        areaLabel: _normalizeNeighborhoodName(rawNeighborhood),
        locality: rawCity,
        administrativeArea: placemark?.administrativeArea?.trim(),
        cityName: _normalizeCityName(rawCity),
        districtName: _normalizeDistrictName(rawDistrict),
        neighborhoodName: _normalizeNeighborhoodName(rawNeighborhood),
        accuracyMeters: position.accuracy,
        capturedAt: DateTime.now(),
      );
      snapshot.value = next;
      history.value = [
        next,
        ...history.value.where((entry) => entry.capturedAt != next.capturedAt),
      ].take(_maxHistoryCount).toList(growable: false);

      final sp = await SharedPreferences.getInstance();
      await sp.setString(_snapshotKey, jsonEncode(next.toJson()));
      await sp.setString(
        _historyKey,
        jsonEncode(history.value.map((entry) => entry.toJson()).toList()),
      );
    } catch (_) {
      // best-effort only
    }
  }

  bool _canUse(LocationPermission permission) {
    return permission != LocationPermission.denied &&
        permission != LocationPermission.deniedForever &&
        permission != LocationPermission.unableToDetermine;
  }
}

String? _firstNonEmpty(List<String?> candidates) {
  for (final value in candidates) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}

bool _looksLikeDistrict(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.endsWith('구') || trimmed.endsWith('군');
}

String? _normalizeCityName(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  return trimmed.replaceAll(RegExp(r'\s+'), ' ');
}

String? _normalizeDistrictName(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  return trimmed.replaceAll(RegExp(r'\s+'), ' ');
}

String? _normalizeNeighborhoodName(String? value) {
  var trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  trimmed = trimmed.replaceAll(RegExp(r'\s+'), ' ');
  trimmed = trimmed.replaceAll(RegExp(r'\s*[0-9]+가$'), '');
  trimmed = trimmed.replaceAll(RegExp(r'\s*제?[0-9]+동$'), '동');
  return trimmed.trim().isEmpty ? null : trimmed.trim();
}
