# NapasPlan

NapasPlan adalah aplikasi Flutter sederhana untuk melihat kualitas udara dan mempertimbangkannya saat merencanakan aktivitas luar ruang.

Pengguna dapat melihat AQI berdasarkan lokasi perangkat atau mencari kota lain, memilih aktivitas, lalu melihat saran dan perkiraan AQI per jam.

## Fitur

- Menampilkan US AQI, PM2.5, dan PM10.
- Mengambil lokasi perangkat setelah izin diberikan.
- Mencari kota di seluruh dunia.
- Memberi saran umum berdasarkan AQI dan aktivitas yang dipilih.
- Menampilkan perkiraan AQI per jam dan waktu dengan kondisi relatif lebih baik.
- Menyimpan aktivitas dan kota terakhir secara lokal.
- Tetap menyediakan pencarian kota manual jika lokasi tidak tersedia.

## Teknologi

- Flutter dan Dart
- Open-Meteo Air Quality API
- Open-Meteo Geocoding API
- Paket `http` untuk permintaan REST API
- Paket `geolocator` untuk lokasi perangkat
- Paket `shared_preferences` untuk penyimpanan lokal

### Kriteria implementasi

- **REST API:** aplikasi mengirim permintaan GET ke Open-Meteo untuk mengambil data kualitas udara dan mencari kota.
- **Asynchronous UI:** permintaan data menggunakan `Future` dan `async`/`await`. UI menampilkan status loading dan pesan error ketika data sedang dimuat atau gagal diperoleh.
- **Local storage:** `SharedPreferencesAsync` menyimpan aktivitas dan kota terakhir yang dipilih. Pada Web, penyimpanan menggunakan browser LocalStorage.

## Menjalankan aplikasi

Pastikan Flutter SDK sudah terpasang. Untuk menjalankan pratinjau Web di Chrome:

```bash
flutter pub get
flutter run -d chrome