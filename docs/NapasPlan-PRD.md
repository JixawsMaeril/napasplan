# PRD — NapasPlan

**Status:** Draf v0.1  
**Platform:** Mobile, Flutter + Dart  
**API AQI:** Belum diputuskan

## Ringkasan

NapasPlan membantu pengguna memutuskan apakah kondisi udara cocok untuk aktivitas luar ruang dan kapan waktu yang lebih baik untuk melakukannya. Aplikasi menampilkan AQI untuk lokasi saat ini, memberi saran sesuai aktivitas pilihan, dan memungkinkan pengguna mencari kota lain di seluruh dunia. Pengalaman utama berada pada satu halaman tanpa akun.

## Masalah dan tujuan

Nilai AQI saja belum menjawab pertanyaan praktis pengguna: “Apakah aman/nyaman melakukan aktivitas ini sekarang, atau sebaiknya menunggu?” NapasPlan mengubah data AQI dan perkiraan per jam menjadi panduan sederhana yang mudah dipahami.

### Tujuan MVP

- Menampilkan AQI terkini untuk lokasi pengguna setelah izin lokasi diberikan.
- Memberi pencarian kota global dan memperbarui halaman untuk kota yang dipilih.
- Membiarkan pengguna memilih aktivitas luar ruang dan melihat kecocokan kondisi udara.
- Menampilkan perkiraan AQI per jam dan waktu yang relatif lebih baik untuk aktivitas tersebut.
- Menyediakan pengalaman tanpa login dan tanpa berpindah dari halaman utama.

### Bukan tujuan MVP

- Akun, profil, sinkronisasi cloud, atau riwayat aktivitas.
- Tantangan, streak, gamifikasi, dan notifikasi.
- Navigasi rute, peta kualitas udara, atau perbandingan banyak kota sekaligus.
- Diagnosis atau nasihat medis personal.

## Pengguna sasaran

Orang yang berencana berjalan kaki, jogging, bersepeda, atau melakukan aktivitas luar ruang lain dan ingin mempertimbangkan kualitas udara sebelum berangkat. Aplikasi ditujukan sebagai panduan informasi umum, bukan pengganti arahan tenaga kesehatan atau otoritas setempat.

## Alur utama

1. Saat dibuka, aplikasi meminta izin lokasi bila status izin belum ditentukan.
2. Jika izin diberikan, aplikasi memperoleh koordinat, menampilkan nama lokasi, lalu mengambil AQI terkini dan perkiraan per jam.
3. Jika izin ditolak atau lokasi tidak tersedia, aplikasi menampilkan pencarian kota manual. Aplikasi tidak mengulang dialog izin secara terus-menerus.
4. Pengguna memilih aktivitas dari halaman utama.
5. Aplikasi menampilkan status kecocokan aktivitas, alasan singkat berdasarkan tingkat AQI, dan waktu perkiraan yang lebih baik bila tersedia.
6. Pengguna dapat mencari kota lain. Hasil pencarian menampilkan nama kota serta wilayah/negara untuk membedakan kota bernama sama. Setelah dipilih, data dan rekomendasi halaman utama diperbarui untuk kota itu.

Pilihan kota hasil pencarian berlaku selama sesi saat ini. Saat aplikasi dibuka kembali, aplikasi mencoba menentukan lokasi perangkat lagi jika izin lokasi tersedia.

## Struktur halaman utama

```text
┌────────────────────────────────────┐
│ NapasPlan        Lokasi / Cari kota │
│ Bandung, Indonesia       [Perbarui] │
├────────────────────────────────────┤
│ AQI 68 · [kategori dari skala API]  │
│ Ringkasan kondisi · diperbarui ... │
├────────────────────────────────────┤
│ Aktivitas: [Jogging              ▾]│
│ Kecocokan + alasan singkat         │
│ Waktu lebih baik: 17.00 (jika ada) │
├────────────────────────────────────┤
│ Perkiraan per jam                  │
│ Sekarang  15.00  16.00  17.00      │
└────────────────────────────────────┘
```

Pencarian kota dapat dibuka dari kontrol lokasi pada halaman yang sama, misalnya sebagai dialog atau bottom sheet. Ini menjaga alur utama tetap satu halaman.

## Persyaratan fungsional

### Lokasi dan kota

- **FR-01:** Aplikasi meminta izin lokasi saat diperlukan dan menjelaskan manfaatnya secara singkat.
- **FR-02:** Jika lokasi tersedia, aplikasi menerjemahkan koordinat menjadi nama kota/wilayah untuk ditampilkan.
- **FR-03:** Jika izin ditolak, layanan lokasi gagal, atau pengguna memilih tidak memberi izin, pencarian kota manual tetap bisa digunakan.
- **FR-04:** Pengguna dapat mencari kota global berdasarkan nama dan memilih hasil yang dibedakan dengan wilayah/negara.
- **FR-05:** Setelah lokasi atau kota berubah, AQI, waktu pembaruan, perkiraan, dan rekomendasi ikut diperbarui.

### AQI dan saran aktivitas

- **FR-06:** Halaman utama menampilkan nilai AQI, skala yang digunakan, kategori/keterangan, dan waktu data.
- **FR-07:** Pengguna dapat memilih aktivitas dari daftar aktivitas luar ruang yang ringkas. Daftar awal yang diusulkan: jalan kaki, jogging/lari, bersepeda, dan olahraga intensitas tinggi.
- **FR-08:** Aplikasi mengaitkan aktivitas dengan tingkat intensitas dan menampilkan saran yang mudah dimengerti, seperti “cocok”, “pertimbangkan mengurangi intensitas”, atau “lebih baik ditunda”.
- **FR-09:** Aplikasi menampilkan perkiraan AQI per jam untuk hari berjalan dan menunjukkan jam dengan kondisi relatif lebih baik bagi aktivitas yang dipilih, jika data memadai.
- **FR-10:** Saran bersifat informatif dan menjelaskan bahwa kualitas udara dapat bervariasi; aplikasi tidak membuat klaim diagnosis atau keselamatan absolut.

### Pembaruan dan keadaan gagal

- **FR-11:** Data dimuat saat aplikasi dibuka, setelah kota dipilih, dan melalui aksi muat ulang.
- **FR-12:** Aplikasi memperbarui data secara berkala ketika halaman sedang aktif; interval awal yang diusulkan adalah 30 menit dan dapat disesuaikan dengan batas API.
- **FR-13:** Jika jaringan/API gagal, aplikasi menampilkan pesan yang jelas, waktu data terakhir yang tersedia bila ada, dan aksi untuk mencoba lagi.
- **FR-14:** Jika kota tidak ditemukan atau hasil terlalu luas, aplikasi meminta pengguna memperjelas pencarian tanpa menghapus layar yang sedang dilihat.

## Persyaratan nonfungsional

- Tidak memerlukan akun atau data identitas.
- Meminta lokasi hanya untuk menentukan kondisi udara; koordinat tidak perlu dikirim ke layanan lain selain penyedia data yang dibutuhkan.
- Tampilkan waktu lokal kota yang dipilih agar prakiraan per jam tidak membingungkan lintas zona waktu.
- Berikan atribusi dan keterangan sumber data sesuai ketentuan penyedia API terpilih.
- Antarmuka harus tetap dapat dipahami saat data belum tersedia, sedang dimuat, atau gagal dimuat.

## Data dan API

Penyedia belum dipilih. Kandidat untuk dievaluasi:

- **Open-Meteo Air Quality API + Geocoding API:** kandidat kuat untuk kebutuhan MVP karena dokumentasinya menyediakan AQI sekarang/per jam, prakiraan global, dan pencarian lokasi. API gratisnya untuk nonkomersial; periksa batas penggunaan dan atribusi yang berlaku sebelum dipakai.
- **WAQI/AQICN API:** alternatif yang menyediakan data AQI, pencarian stasiun, dan perkiraan; memerlukan token dan mempunyai ketentuan atribusi/penggunaan data yang perlu ditinjau.

Sebelum memilih, pastikan API mendukung koordinat global, pencarian kota, nilai AQI terkini, prakiraan per jam, zona waktu, batas pemakaian yang sesuai, serta penggunaan dalam tugas kuliah/aplikasi demonstrasi. Sumber resmi: [Open-Meteo Air Quality](https://open-meteo.com/en/docs/air-quality-api), [Open-Meteo Geocoding](https://open-meteo.com/en/docs/geocoding-api), [Open-Meteo Terms](https://open-meteo.com/en/terms), [WAQI API](https://aqicn.org/api/).

## Aturan rekomendasi

- Gunakan satu skala AQI yang konsisten di seluruh kota dan tampilkan nama skalanya.
- Pemetaan nilai/kategori ke saran harus mengikuti sumber resmi atau panduan kesehatan publik yang relevan dengan skala AQI yang dipilih.
- Intensitas aktivitas dapat memengaruhi bahasa saran; MVP tidak perlu membuat personalisasi medis.
- Bila prakiraan tidak tersedia, tampilkan kondisi sekarang dan nyatakan bahwa waktu terbaik tidak dapat dihitung.
- Jangan menjanjikan aktivitas “aman”; gunakan bahasa panduan seperti “lebih sesuai” atau “pertimbangkan menunda”.
- Tetapkan skala AQI dan aturan saran final setelah API dipilih, lalu gunakan skala yang sama untuk semua kota.

## Kriteria keberhasilan MVP

- Pengguna dapat melihat AQI untuk lokasi saat ini atau kota yang dicari tanpa membuat akun.
- Pengguna dapat mencari dan memilih kota dari hasil global yang cukup jelas untuk dibedakan.
- Memilih aktivitas menghasilkan saran yang konsisten dengan AQI yang ditampilkan.
- Jika data per jam tersedia, halaman menunjukkan waktu dengan perkiraan kondisi relatif lebih baik.
- Izin lokasi ditolak dan kegagalan jaringan tetap memiliki jalur penggunaan yang jelas.

## Keputusan yang masih terbuka

- Penyedia API dan skala AQI yang digunakan.
- Daftar final aktivitas serta aturan kategori/intensitas.
- Interval pembaruan otomatis yang sesuai dengan ketentuan API.
- Aturan kategori/intensitas final setelah skala AQI dan API dipilih.
