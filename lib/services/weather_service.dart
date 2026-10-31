import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Represents the approximate weather location of a Zambian province.
class ProvinceLocation {
  final String province;
  final String town;
  final double latitude;
  final double longitude;

  const ProvinceLocation({
    required this.province,
    required this.town,
    required this.latitude,
    required this.longitude,
  });
}

/// Retrieves current weather and forecasts using the Open-Meteo API.
class WeatherService {
  static const Map<String, ProvinceLocation> provinceLocations = {
    'Central': ProvinceLocation(
      province: 'Central',
      town: 'Kabwe',
      latitude: -14.4469,
      longitude: 28.4464,
    ),
    'Copperbelt': ProvinceLocation(
      province: 'Copperbelt',
      town: 'Ndola',
      latitude: -12.9587,
      longitude: 28.6366,
    ),
    'Eastern': ProvinceLocation(
      province: 'Eastern',
      town: 'Chipata',
      latitude: -13.6333,
      longitude: 32.6500,
    ),
    'Luapula': ProvinceLocation(
      province: 'Luapula',
      town: 'Mansa',
      latitude: -11.1998,
      longitude: 28.8943,
    ),
    'Lusaka': ProvinceLocation(
      province: 'Lusaka',
      town: 'Lusaka',
      latitude: -15.3875,
      longitude: 28.3228,
    ),
    'Muchinga': ProvinceLocation(
      province: 'Muchinga',
      town: 'Chinsali',
      latitude: -10.5414,
      longitude: 32.0816,
    ),
    'Northern': ProvinceLocation(
      province: 'Northern',
      town: 'Kasama',
      latitude: -10.2129,
      longitude: 31.1808,
    ),
    'North-Western': ProvinceLocation(
      province: 'North-Western',
      town: 'Solwezi',
      latitude: -12.1688,
      longitude: 26.3894,
    ),
    'Southern': ProvinceLocation(
      province: 'Southern',
      town: 'Choma',
      latitude: -16.8089,
      longitude: 26.9875,
    ),
    'Western': ProvinceLocation(
      province: 'Western',
      town: 'Mongu',
      latitude: -15.2484,
      longitude: 23.1274,
    ),
  };

  final http.Client _client;

  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  /// Gets current weather and a five-day forecast for a province.
  Future<WeatherData> getWeather(String province) async {
    final location = provinceLocations[province];

    if (location == null) {
      throw WeatherException(
        'Weather location is not available for $province.',
      );
    }

    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': location.latitude.toString(),
      'longitude': location.longitude.toString(),
      'current':
          'temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,rain,showers,weather_code,wind_speed_10m',
      'daily':
          'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum',
      'timezone': 'Africa/Lusaka',
      'forecast_days': '5',
    });

    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw WeatherException(
          'Weather service returned an error. Please try again later.',
        );
      }

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;

      final current = data['current'];

      if (current is! Map<String, dynamic>) {
        throw WeatherException('Current weather information is unavailable.');
      }

      final daily = data['daily'];

      if (daily is! Map<String, dynamic>) {
        throw WeatherException('Weather forecast information is unavailable.');
      }

      final forecasts = _parseForecast(daily);

      return WeatherData(
        currentTemperature: _number(current['temperature_2m']),
        feelsLike: _number(current['apparent_temperature']),
        humidity: _integer(current['relative_humidity_2m']),
        windSpeed: _number(current['wind_speed_10m']),
        precipitation: _number(current['precipitation']),
        condition: weatherDescription(_integer(current['weather_code'])),
        weatherCode: _integer(current['weather_code']),
        forecast: forecasts,
        fetchedAt: DateTime.now(),
      );
    } on TimeoutException {
      throw WeatherException(
        'The weather request timed out. Check your internet connection.',
      );
    } on WeatherException {
      rethrow;
    } catch (error) {
      throw WeatherException(
        'Unable to retrieve weather information. Please check your connection and try again.',
      );
    }
  }

  /// Converts the daily API response into forecast objects.
  List<DailyForecast> _parseForecast(Map<String, dynamic> daily) {
    final dates = daily['time'];
    final minimums = daily['temperature_2m_min'];
    final maximums = daily['temperature_2m_max'];
    final probabilities = daily['precipitation_probability_max'];
    final rainfall = daily['precipitation_sum'];
    final codes = daily['weather_code'];

    if (dates is! List ||
        minimums is! List ||
        maximums is! List ||
        probabilities is! List ||
        rainfall is! List ||
        codes is! List) {
      throw WeatherException('The weather forecast data is incomplete.');
    }

    final forecasts = <DailyForecast>[];

    for (int i = 0; i < dates.length; i++) {
      forecasts.add(
        DailyForecast(
          date: dates[i].toString(),
          minimumTemperature: _number(minimums[i]),
          maximumTemperature: _number(maximums[i]),
          rainProbability: _integer(probabilities[i]),
          rainfall: _number(rainfall[i]),
          weatherCode: _integer(codes[i]),
          condition: weatherDescription(_integer(codes[i])),
        ),
      );
    }

    return forecasts;
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return 0.0;
  }

  int _integer(dynamic value) {
    if (value is num) return value.round();
    return 0;
  }

  /// Releases the HTTP client when the screen is disposed.
  void dispose() {
    _client.close();
  }
}

/// Represents current weather and the five-day forecast.
class WeatherData {
  final double currentTemperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final double precipitation;
  final String condition;
  final int weatherCode;
  final List<DailyForecast> forecast;
  final DateTime fetchedAt;

  WeatherData({
    required this.currentTemperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.precipitation,
    required this.condition,
    required this.weatherCode,
    required this.forecast,
    required this.fetchedAt,
  });
}

/// Represents one day in the weather forecast.
class DailyForecast {
  final String date;
  final double minimumTemperature;
  final double maximumTemperature;
  final int rainProbability;
  final double rainfall;
  final int weatherCode;
  final String condition;

  DailyForecast({
    required this.date,
    required this.minimumTemperature,
    required this.maximumTemperature,
    required this.rainProbability,
    required this.rainfall,
    required this.weatherCode,
    required this.condition,
  });
}

/// Represents an error returned by the weather service.
class WeatherException implements Exception {
  final String message;

  WeatherException(this.message);

  @override
  String toString() => message;
}

/// Converts Open-Meteo weather codes into readable descriptions.
String weatherDescription(int code) {
  if (code == 0) return 'Clear sky';
  if (code == 1) return 'Mainly clear';
  if (code == 2) return 'Partly cloudy';
  if (code == 3) return 'Overcast';

  if (code == 45 || code == 48) return 'Foggy';

  if (code >= 51 && code <= 55) return 'Drizzle';
  if (code >= 56 && code <= 57) return 'Freezing drizzle';

  if (code >= 61 && code <= 65) return 'Rain';
  if (code >= 66 && code <= 67) return 'Freezing rain';

  if (code >= 71 && code <= 77) return 'Snow';

  if (code >= 80 && code <= 82) return 'Rain showers';

  if (code == 85 || code == 86) return 'Snow showers';

  if (code == 95) return 'Thunderstorm';
  if (code == 96 || code == 99) {
    return 'Thunderstorm with hail';
  }

  return 'Weather conditions unavailable';
}
