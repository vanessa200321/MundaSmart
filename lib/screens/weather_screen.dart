
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/weather_service.dart';

const Color weatherForestGreen = Color(0xFF2E7D32);
const Color weatherLightGreen = Color(0xFFE8F5E9);

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  late final WeatherService weatherService;

  WeatherData? weather;
  String province = '';
  String town = '';
  String? errorMessage;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    weatherService = WeatherService();
    loadWeather();
  }

  @override
  void dispose() {
    weatherService.dispose();
    super.dispose();
  }

  Future<void> loadWeather() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedProvince = prefs.getString('farmer_location');

      if (savedProvince == null || savedProvince.trim().isEmpty) {
        throw WeatherException(
          'Please set your farming province in your profile first.',
        );
      }

      final cleanedProvince = savedProvince
          .trim()
          .replaceFirst(
            RegExp(r'\s+Province$', caseSensitive: false),
            '',
          );

      final location =
          WeatherService.provinceLocations[cleanedProvince];

      if (location == null) {
        throw WeatherException(
          'Weather is not configured for $savedProvince.',
        );
      }

      final result = await weatherService.getWeather(cleanedProvince);

      if (!mounted) return;

      setState(() {
        province = location.province;
        town = location.town;
        weather = result;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = error is WeatherException
            ? error.message
            : 'Unable to load live weather. Please check your internet connection and try again.';
        loading = false;
      });
    }
  }

  IconData weatherIcon(int code) {
    if (code == 0 || code == 1) {
      return Icons.wb_sunny;
    }

    if (code == 2 || code == 3) {
      return Icons.cloud;
    }

    if (code == 45 || code == 48) {
      return Icons.foggy;
    }

    if (code >= 51 && code <= 67) {
      return Icons.grain;
    }

    if (code >= 71 && code <= 86) {
      return Icons.ac_unit;
    }

    if (code >= 80 && code <= 82) {
      return Icons.water_drop;
    }

    if (code >= 95) {
      return Icons.thunderstorm;
    }

    return Icons.cloud_outlined;
  }

  String formatDate(String date) {
    try {
      final parsed = DateTime.parse(date);
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];

      return '${parsed.day} ${months[parsed.month - 1]}';
    } catch (_) {
      return date;
    }
  }

  Widget detailTile(
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: weatherLightGreen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: weatherForestGreen),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: weatherForestGreen),
            SizedBox(height: 16),
            Text('Loading weather information...'),
          ],
        ),
      );
    }

    if (errorMessage != null || weather == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off,
                size: 65,
                color: weatherForestGreen,
              ),
              const SizedBox(height: 16),
              const Text(
                'Weather unavailable',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                errorMessage ?? 'Weather information could not be loaded.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: weatherLightGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: weatherForestGreen),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Live weather needs an internet connection. Your saved farming profile, advice and calendar remain available offline.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: loadWeather,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final current = weather!;

    return RefreshIndicator(
      onRefresh: loadWeather,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on,
                color: weatherForestGreen,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$town, $province Province',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
              IconButton(
                onPressed: loadWeather,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh weather',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: weatherLightGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(
                  weatherIcon(current.weatherCode),
                  size: 65,
                  color: weatherForestGreen,
                ),
                const SizedBox(height: 12),
                Text(
                  '${current.currentTemperature.round()}°C',
                  style: const TextStyle(
                    fontSize: 45,
                    fontWeight: FontWeight.bold,
                    color: weatherForestGreen,
                  ),
                ),
                Text(
                  current.condition,
                  style: const TextStyle(fontSize: 19),
                ),
                const SizedBox(height: 8),
                Text(
                  'Feels like ${current.feelsLike.round()}°C',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Current conditions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              detailTile(
                Icons.water_drop,
                'Humidity',
                '${current.humidity}%',
              ),
              detailTile(
                Icons.air,
                'Wind speed',
                '${current.windSpeed} km/h',
              ),
              detailTile(
                Icons.umbrella,
                'Precipitation',
                '${current.precipitation} mm',
              ),
              detailTile(
                Icons.thermostat,
                'Feels like',
                '${current.feelsLike.round()}°C',
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Five-day forecast',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...current.forecast.map(
            (day) => Card(
              child: ListTile(
                leading: Icon(
                  weatherIcon(day.weatherCode),
                  color: weatherForestGreen,
                  size: 30,
                ),
                title: Text(formatDate(day.date)),
                subtitle: Text(
                  '${day.condition} • Rain chance: ${day.rainProbability}%',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${day.maximumTemperature.round()}° / ${day.minimumTemperature.round()}°',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('${day.rainfall} mm rain'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: weatherLightGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Farming note',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Use this forecast as a planning guide. Check actual soil moisture and local conditions before planting, applying fertiliser or spraying crops. Forecasts can change.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Weather location uses $town as a representative location for $province Province. Conditions may differ in other districts.',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Weather data provided by Open-Meteo.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          Text(
            'Last updated: ${current.fetchedAt}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
