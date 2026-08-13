import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;

/// Executable tools the voice agent can call via Gemini function calling.
class AgentTools {
  AgentTools({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, Object?>> getWeather(Map<String, Object?> args) async {
    final city = (args['city'] as String?)?.trim();
    if (city == null || city.isEmpty) {
      return {'error': 'A city name is required.'};
    }

    try {
      final geoUri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
        'name': city,
        'count': '1',
        'language': 'en',
        'format': 'json',
      });
      final geoRes = await _client.get(geoUri);
      if (geoRes.statusCode != 200) {
        return {'error': 'Failed to look up "$city".'};
      }

      final geoJson = jsonDecode(geoRes.body) as Map<String, dynamic>;
      final results = geoJson['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) {
        return {'error': 'Could not find a location named "$city".'};
      }

      final place = results.first as Map<String, dynamic>;
      final lat = place['latitude'];
      final lon = place['longitude'];
      final resolvedName = [
        place['name'],
        place['admin1'],
        place['country'],
      ].whereType<String>().join(', ');

      final weatherUri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '$lat',
        'longitude': '$lon',
        'current': 'temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m',
        'temperature_unit': 'celsius',
        'wind_speed_unit': 'kmh',
      });
      final weatherRes = await _client.get(weatherUri);
      if (weatherRes.statusCode != 200) {
        return {'error': 'Weather service unavailable for $resolvedName.'};
      }

      final weatherJson = jsonDecode(weatherRes.body) as Map<String, dynamic>;
      final current = weatherJson['current'] as Map<String, dynamic>?;
      if (current == null) {
        return {'error': 'No current weather data for $resolvedName.'};
      }

      final code = current['weather_code'] as int? ?? -1;
      return {
        'location': resolvedName,
        'temperature_c': current['temperature_2m'],
        'humidity_percent': current['relative_humidity_2m'],
        'wind_speed_kmh': current['wind_speed_10m'],
        'conditions': _weatherCodeLabel(code),
        'source': 'Open-Meteo',
      };
    } catch (e, stackTrace) {
      log('getWeather failed: $e', stackTrace: stackTrace);
      return {'error': 'Unable to fetch weather right now.'};
    }
  }

  Future<Map<String, Object?>> getCurrentTime(Map<String, Object?> args) async {
    final now = DateTime.now().toLocal();
    final locationHint = (args['location_hint'] as String?)?.trim();
    return {
      'iso8601': now.toIso8601String(),
      'formatted':
          '${_weekday(now.weekday)}, ${now.day} ${_month(now.month)} ${now.year} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      'timezone_offset_minutes': now.timeZoneOffset.inMinutes,
      'timezone_name': now.timeZoneName,
      if (locationHint != null && locationHint.isNotEmpty)
        'note':
            'Device local time returned. Location hint "$locationHint" was acknowledged but not converted.',
    };
  }

  Future<Map<String, Object?>> tellJoke(Map<String, Object?> args) async {
    final topic = ((args['topic'] as String?)?.trim().isNotEmpty ?? false)
        ? (args['topic'] as String).trim()
        : 'general';

    final jokes = <String, List<String>>{
      'tech': [
        'There are only 10 kinds of people: those who understand binary and those who don’t.',
        'A SQL query walks into a bar, walks up to two tables and asks: can I join you?',
      ],
      'weather': [
        'I tried to catch the fog yesterday… I mist.',
        'The weather forecast said “cloudy with a chance of meatballs.” I brought a fork.',
      ],
      'general': [
        'Why don’t scientists trust atoms? Because they make up everything.',
        'I told my computer I needed a break… and it froze.',
      ],
    };

    final key = jokes.containsKey(topic.toLowerCase())
        ? topic.toLowerCase()
        : 'general';
    final pool = jokes[key]!;
    final joke = pool[DateTime.now().millisecond % pool.length];

    return {
      'topic': topic,
      'joke': joke,
    };
  }

  String _weatherCodeLabel(int code) {
    return switch (code) {
      0 => 'Clear sky',
      1 || 2 || 3 => 'Partly cloudy',
      45 || 48 => 'Foggy',
      51 || 53 || 55 => 'Drizzle',
      61 || 63 || 65 => 'Rain',
      71 || 73 || 75 => 'Snow',
      80 || 81 || 82 => 'Rain showers',
      95 || 96 || 99 => 'Thunderstorm',
      _ => 'Mixed conditions',
    };
  }

  String _weekday(int day) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[day - 1];
  }

  String _month(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[month - 1];
  }
}
