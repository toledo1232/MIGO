import 'dart:convert';
import 'dart:io';

import 'package:google_maps_flutter/google_maps_flutter.dart';

class LiveTripRoute {
  const LiveTripRoute({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
  });

  final List<LatLng> points;
  final double distanceKm;
  final int durationMinutes;
}

class LiveTripApi {
  static const String apiBaseUrl = 'http://10.0.2.2:8000/api/v1';

  static Future<dynamic> requestJson({
    required String method,
    required String path,
    Map<String, dynamic>? body,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);

    try {
      final uri = Uri.parse('$apiBaseUrl$path');
      final HttpClientRequest request;

      switch (method) {
        case 'GET':
          request = await client.getUrl(uri);
          break;
        case 'POST':
          request = await client.postUrl(uri);
          break;
        default:
          throw UnsupportedError('Método HTTP no soportado: $method');
      }

      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);

      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close();
      final raw = await utf8.decoder.bind(response).join();

      dynamic decoded;
      if (raw.trim().isEmpty) {
        decoded = null;
      } else {
        decoded = jsonDecode(raw);
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        var detail = 'HTTP ${response.statusCode}';

        if (decoded is Map<String, dynamic>) {
          detail = decoded['detail']?.toString() ?? detail;
        }

        throw HttpException(detail);
      }

      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  static Future<Map<String, dynamic>> getRide(String requestId) async {
    final data = await requestJson(
      method: 'GET',
      path: '/ride-requests/$requestId',
    );

    if (data is! Map<String, dynamic>) {
      throw const FormatException('Respuesta de viaje inválida.');
    }

    return data;
  }

  static Future<Map<String, dynamic>> postRideAction(
    String requestId,
    String action, {
    Map<String, dynamic>? body,
  }) async {
    final data = await requestJson(
      method: 'POST',
      path: '/ride-requests/$requestId/$action',
      body: body,
    );

    if (data is! Map<String, dynamic>) {
      throw const FormatException('Respuesta de viaje inválida.');
    }

    return data;
  }

  static Future<LiveTripRoute?> computeRoute(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final data = await requestJson(
        method: 'POST',
        path: '/routes/compute',
        body: {
          'origin': {
            'latitude': origin.latitude,
            'longitude': origin.longitude,
          },
          'destination': {
            'latitude': destination.latitude,
            'longitude': destination.longitude,
          },
        },
      );

      if (data is! Map<String, dynamic>) {
        return null;
      }

      final encoded = data['encoded_polyline']?.toString();
      if (encoded == null || encoded.isEmpty) {
        return null;
      }

      final points = decodePolyline(encoded);
      if (points.isEmpty) {
        return null;
      }

      return LiveTripRoute(
        points: points,
        distanceKm: (data['distance_km'] as num?)?.toDouble() ?? 0,
        durationMinutes: (data['duration_minutes'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  static LatLng? pointFromRide(Map<String, dynamic> ride, String prefix) {
    final lat = (ride['${prefix}_lat'] as num?)?.toDouble();
    final lng = (ride['${prefix}_lng'] as num?)?.toDouble();

    if (lat == null || lng == null) {
      return null;
    }

    return LatLng(lat, lng);
  }

  static List<LatLng> decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int byte;

      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);

      final deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += deltaLat;

      shift = 0;
      result = 0;

      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1F) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);

      final deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += deltaLng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  static LatLngBounds boundsFor(List<LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final point in points.skip(1)) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    if ((maxLat - minLat).abs() < 0.0005) {
      minLat -= 0.0005;
      maxLat += 0.0005;
    }

    if ((maxLng - minLng).abs() < 0.0005) {
      minLng -= 0.0005;
      maxLng += 0.0005;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}
