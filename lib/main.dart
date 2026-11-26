import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const NapasPlanApp());
}

class NapasPlanApp extends StatelessWidget {
  const NapasPlanApp({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF267768);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NapasPlan',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: green),
        scaffoldBackgroundColor: const Color(0xFFF4F7F5),
      ),
      home: const HomePage(),
    );
  }
}

// -------------------- Data dan API --------------------

class City {
  const City({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.country,
    this.region,
  });

  final String name;
  final double latitude;
  final double longitude;
  final String country;
  final String? region;

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      name: json['name'] as String? ?? 'Kota',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      country: json['country'] as String? ?? '',
      region: json['admin1'] as String?,
    );
  }

  String get subtitle {
    final parts = <String>[];
    if (region != null && region!.isNotEmpty && region != name) {
      parts.add(region!);
    }
    if (country.isNotEmpty) parts.add(country);
    return parts.join(', ');
  }
}

class HourlyAqi {
  const HourlyAqi({required this.time, required this.aqi});

  final String time;
  final int aqi;

  String get hourLabel {
    if (time.length >= 16) return time.substring(11, 16);
    return time;
  }
}

class AirQualityData {
  const AirQualityData({
    required this.aqi,
    required this.pm25,
    required this.pm10,
    required this.currentTime,
    required this.forecast,
  });

  final int? aqi;
  final double? pm25;
  final double? pm10;
  final String currentTime;
  final List<HourlyAqi> forecast;

  factory AirQualityData.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>? ?? {};
    final hourly = json['hourly'] as Map<String, dynamic>? ?? {};
    final times = (hourly['time'] as List<dynamic>? ?? []).cast<String>();
    final values = hourly['us_aqi'] as List<dynamic>? ?? [];

    final forecast = <HourlyAqi>[];
    for (var i = 0; i < times.length && i < values.length; i++) {
      final value = values[i];
      if (value is num) {
        forecast.add(HourlyAqi(time: times[i], aqi: value.round()));
      }
    }

    return AirQualityData(
      aqi: (current['us_aqi'] as num?)?.round(),
      pm25: (current['pm2_5'] as num?)?.toDouble(),
      pm10: (current['pm10'] as num?)?.toDouble(),
      currentTime: current['time'] as String? ?? '',
      forecast: forecast,
    );
  }

  int get currentForecastIndex {
    if (forecast.isEmpty || currentTime.length < 13) return 0;

    final currentHour = currentTime.substring(0, 13);
    final exactIndex = forecast.indexWhere(
      (item) => item.time.length >= 13 && item.time.substring(0, 13) == currentHour,
    );
    if (exactIndex >= 0) return exactIndex;

    final nextIndex = forecast.indexWhere(
      (item) => item.time.length >= 13 && item.time.substring(0, 13).compareTo(currentHour) >= 0,
    );
    return nextIndex >= 0 ? nextIndex : 0;
  }

  List<HourlyAqi> get upcomingHours {
    if (forecast.isEmpty) return [];
    return forecast.skip(currentForecastIndex).take(6).toList();
  }

  HourlyAqi? get bestUpcomingHour {
    if (forecast.isEmpty) return null;

    final start = currentForecastIndex + 1;
    if (start >= forecast.length) return null;

    final nextHours = forecast.skip(start).take(12).toList();
    if (nextHours.isEmpty) return null;

    nextHours.sort((a, b) => a.aqi.compareTo(b.aqi));
    return nextHours.first;
  }
}

class OpenMeteoService {
  Future<List<City>> searchCities(String query) async {
    final uri = Uri.https(
      'geocoding-api.open-meteo.com',
      '/v1/search',
      {
        'name': query,
        'count': '8',
        'language': 'id',
        'format': 'json',
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Pencarian kota gagal.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final results = json['results'] as List<dynamic>? ?? [];

    return results
        .whereType<Map<String, dynamic>>()
        .map(City.fromJson)
        .toList();
  }

  Future<AirQualityData> getAirQuality({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.https(
      'air-quality-api.open-meteo.com',
      '/v1/air-quality',
      {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'current': 'us_aqi,pm2_5,pm10',
        'hourly': 'us_aqi',
        'forecast_hours': '24',
        'timezone': 'auto',
      },
    );

    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Data kualitas udara tidak bisa dimuat.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return AirQualityData.fromJson(json);
  }
}

// -------------------- Aktivitas dan saran --------------------

enum OutdoorActivity {
  walking,
  cycling,
  jogging,
  intenseExercise,
}

extension OutdoorActivityInfo on OutdoorActivity {
  String get label {
    switch (this) {
      case OutdoorActivity.walking:
        return 'Jalan santai';
      case OutdoorActivity.cycling:
        return 'Bersepeda';
      case OutdoorActivity.jogging:
        return 'Jogging';
      case OutdoorActivity.intenseExercise:
        return 'Olahraga intens';
    }
  }

  IconData get icon {
    switch (this) {
      case OutdoorActivity.walking:
        return Icons.directions_walk;
      case OutdoorActivity.cycling:
        return Icons.directions_bike;
      case OutdoorActivity.jogging:
        return Icons.directions_run;
      case OutdoorActivity.intenseExercise:
        return Icons.fitness_center;
    }
  }

  bool get isIntense =>
      this == OutdoorActivity.jogging ||
      this == OutdoorActivity.intenseExercise;
}

class AqiCategory {
  const AqiCategory({
    required this.label,
    required this.color,
    required this.message,
  });

  final String label;
  final Color color;
  final String message;
}

AqiCategory categoryForAqi(int aqi) {
  if (aqi <= 50) {
    return const AqiCategory(
      label: 'Baik',
      color: Color(0xFF2E9B69),
      message: 'Udara baik untuk aktivitas luar ruang.',
    );
  }
  if (aqi <= 100) {
    return const AqiCategory(
      label: 'Sedang',
      color: Color(0xFFE0A82E),
      message: 'Kualitas udara cukup baik untuk kebanyakan orang.',
    );
  }
  if (aqi <= 150) {
    return const AqiCategory(
      label: 'Kurang sehat bagi kelompok sensitif',
      color: Color(0xFFDE7837),
      message: 'Kelompok sensitif sebaiknya membatasi aktivitas di luar.',
    );
  }
  if (aqi <= 200) {
    return const AqiCategory(
      label: 'Tidak sehat',
      color: Color(0xFFD94A4A),
      message: 'Pertimbangkan mengurangi aktivitas di luar.',
    );
  }
  if (aqi <= 300) {
    return const AqiCategory(
      label: 'Sangat tidak sehat',
      color: Color(0xFF8E55A5),
      message: 'Lebih baik memilih aktivitas di dalam ruangan.',
    );
  }
  return const AqiCategory(
    label: 'Berbahaya',
    color: Color(0xFF7C3448),
    message: 'Sebaiknya lakukan aktivitas di dalam ruangan.',
  );
}

String adviceForActivity(int aqi, OutdoorActivity activity) {
  if (aqi <= 50) {
    return '${activity.label} cocok dilakukan sekarang.';
  }
  if (aqi <= 100) {
    return activity.isIntense
        ? 'Masih bisa dilakukan. Pertimbangkan mengurangi intensitas.'
        : '${activity.label} masih cocok dilakukan.';
  }
  if (aqi <= 150) {
    return activity.isIntense
        ? 'Kurangi intensitas atau pilih waktu dengan AQI lebih rendah.'
        : 'Aktivitas ringan masih bisa dipertimbangkan.';
  }
  if (aqi <= 200) {
    return 'Pertimbangkan menunda atau beraktivitas di dalam ruangan.';
  }
  return 'Pilih aktivitas di dalam ruangan untuk saat ini.';
}

// -------------------- Halaman utama --------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _api = OpenMeteoService();
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  AirQualityData? _data;
  double? _latitude;
  double? _longitude;

  String _locationLabel = 'Mencari lokasi...';
  String? _error;
  bool _loading = true;
  bool _usingDeviceLocation = true;
  OutdoorActivity _activity = OutdoorActivity.walking;

  late final Timer _refreshTimer;

  @override
  void initState() {
    super.initState();

    _refreshTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      if (_latitude != null && !_loading) {
        _loadAirQuality();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    super.dispose();
  }

  Future<bool> _loadDeviceLocation() async {
    setState(() {
      _loading = true;
      _error = null;
      _locationLabel = 'Mencari lokasi...';
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Layanan lokasi tidak aktif.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Izin lokasi tidak diberikan.');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );

      _latitude = position.latitude;
      _longitude = position.longitude;
      _usingDeviceLocation = true;
      _locationLabel = 'Lokasi saat ini';

      await _loadAirQuality();
      return true;
    } catch (_) {
      if (!mounted) return false;

      setState(() {
        _loading = false;
        _locationLabel = 'Lokasi belum tersedia';
        _error = 'Izinkan lokasi atau cari kota secara manual.';
      });

      return false;
    }
  }

  Future<void> _loadAirQuality() async {
    if (_latitude == null || _longitude == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _api.getAirQuality(
        latitude: _latitude!,
        longitude: _longitude!,
      );
      if (!mounted) return;
      setState(() {
        _data = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Data AQI gagal dimuat. Periksa internet lalu coba lagi.';
      });
    }
  }

  Future<void> _saveActivity(OutdoorActivity activity) async {
    await _preferences.setString('selected_activity', activity.name);
  }

  Future<void> _initializeApp() async {
    try {
      final savedActivity = await _preferences.getString('selected_activity');

      if (!mounted) return;

      for (final activity in OutdoorActivity.values) {
        if (activity.name == savedActivity) {
          setState(() => _activity = activity);
          break;
        }
      }

      final savedCityName = await _preferences.getString('last_city_name');
      final savedLatitude =
          await _preferences.getDouble('last_city_latitude');
      final savedLongitude =
          await _preferences.getDouble('last_city_longitude');

      // Lokasi perangkat tetap menjadi pilihan utama.
      final locationLoaded = await _loadDeviceLocation();

      // Kalau lokasi tidak tersedia, gunakan kota yang tersimpan.
      if (!locationLoaded &&
          savedCityName != null &&
          savedLatitude != null &&
          savedLongitude != null &&
          mounted) {
        setState(() {
          _locationLabel = savedCityName;
          _latitude = savedLatitude;
          _longitude = savedLongitude;
          _usingDeviceLocation = false;
        });

        await _loadAirQuality();
      }
    } catch (_) {
      // Tetap coba lokasi perangkat jika pembacaan storage gagal.
      await _loadDeviceLocation();
    }
  }

  Future<void> _refresh() async {
    if (_usingDeviceLocation) {
      await _loadDeviceLocation();
    } else {
      await _loadAirQuality();
    }
  }

  Future<void> _openCitySearch() async {
    final city = await showModalBottomSheet<City>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => CitySearchSheet(api: _api),
    );

    if (city == null || !mounted) return;

    setState(() {
      _latitude = city.latitude;
      _longitude = city.longitude;
      _locationLabel = city.name;
      _usingDeviceLocation = false;
      
    });

    await _preferences.setString('last_city_name', city.name);
    await _preferences.setDouble('last_city_latitude', city.latitude);
    await _preferences.setDouble('last_city_longitude', city.longitude);
    await _loadAirQuality();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final aqi = data?.aqi;
    final category = aqi == null ? null : categoryForAqi(aqi);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NapasPlan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Cari kota',
            onPressed: _openCitySearch,
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined, color: Color(0xFF267768)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _locationLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _openCitySearch,
                  child: const Text('Ganti kota'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_error != null) _ErrorBanner(message: _error!),

            if (data == null && _loading)
              const _LoadingCard()
            else if (data == null)
              _EmptyCard(onSearch: _openCitySearch)
            else if (aqi != null && category != null)
              _AqiCard(
                aqi: aqi,
                category: category,
                pm25: data.pm25,
                pm10: data.pm10,
                updateTime: data.currentTime,
                loading: _loading,
              ),

            const SizedBox(height: 18),

            _ActivityCard(
              activity: _activity,
              onChanged: (value) {
                setState(() => _activity = value);
                unawaited(_saveActivity(value));
              },
              advice: aqi == null ? null : adviceForActivity(aqi, _activity),
              adviceColor: category?.color,
            ),

            if (data != null) ...[
              const SizedBox(height: 18),
              _ForecastCard(data: data),
            ],

            const SizedBox(height: 22),
            const Center(
              child: Text(
                'Data kualitas udara: Open-Meteo · Skala: US AQI\n'
                'Saran ini merupakan panduan informasi umum.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF66736D)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------- Komponen tampilan --------------------

class _AqiCard extends StatelessWidget {
  const _AqiCard({
    required this.aqi,
    required this.category,
    required this.pm25,
    required this.pm10,
    required this.updateTime,
    required this.loading,
  });

  final int aqi;
  final AqiCategory category;
  final double? pm25;
  final double? pm10;
  final String updateTime;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final time = updateTime.length >= 16
        ? updateTime.substring(11, 16)
        : updateTime;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kualitas udara sekarang',
                      style: TextStyle(color: Color(0xFF66736D)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$aqi',
                      style: TextStyle(
                        color: category.color,
                        fontSize: 60,
                        height: 1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      category.label,
                      style: TextStyle(
                        color: category.color,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.air, size: 42, color: category.color),
            ],
          ),
          const SizedBox(height: 16),
          Text(category.message),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (aqi.clamp(0, 300) / 300).toDouble(),
              minHeight: 8,
              color: category.color,
              backgroundColor: const Color(0xFFE8EEEA),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _PollutantChip(label: 'PM2.5', value: pm25),
              _PollutantChip(label: 'PM10', value: pm10),
            ],
          ),
          if (time.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Waktu data: $time',
              style: const TextStyle(fontSize: 12, color: Color(0xFF66736D)),
            ),
          ],
        ],
      ),
    );
  }
}

class _PollutantChip extends StatelessWidget {
  const _PollutantChip({required this.label, required this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        value == null ? '$label: —' : '$label: ${value!.toStringAsFixed(1)} µg/m³',
      ),
      backgroundColor: const Color(0xFFF0F4F1),
      side: BorderSide.none,
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.activity,
    required this.onChanged,
    required this.advice,
    required this.adviceColor,
  });

  final OutdoorActivity activity;
  final ValueChanged<OutdoorActivity> onChanged;
  final String? advice;
  final Color? adviceColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rencana aktivitas',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<OutdoorActivity>(
            initialValue: activity,
            decoration: InputDecoration(
              prefixIcon: Icon(activity.icon, color: const Color(0xFF267768)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            items: OutdoorActivity.values
                .map(
                  (item) => DropdownMenuItem(
                    value: item,
                    child: Text(item.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
          const SizedBox(height: 14),
          if (advice != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (adviceColor ?? const Color(0xFF267768)).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: adviceColor ?? const Color(0xFF267768),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(advice!)),
                ],
              ),
            )
          else
            const Text('Pilih kota untuk melihat saran aktivitas.'),
        ],
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.data});

  final AirQualityData data;

  @override
  Widget build(BuildContext context) {
    final hours = data.upcomingHours;
    final bestTime = data.bestUpcomingHour;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Perkiraan AQI per jam',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (bestTime != null) ...[
            const SizedBox(height: 6),
            Text(
              'Waktu dengan perkiraan relatif lebih baik: ${bestTime.hourLabel}',
              style: const TextStyle(color: Color(0xFF267768)),
            ),
          ],
          const SizedBox(height: 14),
          if (hours.isEmpty)
            const Text('Data perkiraan per jam belum tersedia.')
          else
            SizedBox(
              height: 82,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: hours.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final item = hours[index];
                  final category = categoryForAqi(item.aqi);

                  return Container(
                    width: 76,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7F5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.hourLabel,
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${item.aqi}',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: category.color,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('Memuat data kualitas udara...'),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const Icon(Icons.location_searching, size: 38),
            const SizedBox(height: 10),
            const Text(
              'Lokasi belum dipilih',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text('Cari kota untuk melihat kualitas udara.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onSearch,
              icon: const Icon(Icons.search),
              label: const Text('Cari kota'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0E8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFB65B2D)),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

// -------------------- Pencarian kota --------------------

class CitySearchSheet extends StatefulWidget {
  const CitySearchSheet({super.key, required this.api});

  final OpenMeteoService api;

  @override
  State<CitySearchSheet> createState() => _CitySearchSheetState();
}

class _CitySearchSheetState extends State<CitySearchSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<City> _results = [];
  bool _searching = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();

    if (query.length < 2) {
      setState(() {
        _results = [];
        _error = null;
        _searching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final results = await widget.api.searchCities(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = 'Pencarian gagal. Periksa koneksi internet.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 18,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cari kota',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Contoh: Jakarta, Tokyo, London',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_searching) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_error!),
              ),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        _controller.text.trim().length < 2
                            ? 'Ketik minimal 2 huruf untuk mencari.'
                            : _searching
                                ? 'Mencari kota...'
                                : 'Tidak ada hasil.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final city = _results[index];
                        return ListTile(
                          leading: const Icon(Icons.location_city),
                          title: Text(city.name),
                          subtitle: Text(city.subtitle),
                          onTap: () => Navigator.pop(context, city),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}