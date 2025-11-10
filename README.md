# EsaGo

EsaGo adalah asisten akademik all-in-one resmi untuk mahasiswa Universitas Esa Unggul, dirancang untuk menyederhanakan kehidupan kampus Anda dari A sampai Z. Dari jadwal kuliah hingga administrasi UKT, semuanya ada di sini—ditambah kecerdasan buatan (AI) yang siap mendampingi studi Anda!

## 🚀 Fitur

- **Login Single Sign-On (SSO)**: Masuk dengan cepat dan aman menggunakan akun SSO universitas Anda.
- **Jadwal Kuliah**: Lihat jadwal kelas Anda yang akan datang dalam antarmuka yang mudah digunakan.
- **Profil Mahasiswa**: Akses informasi profil akademik Anda kapan saja.
- **Daftar Peserta Kelas**: Lihat siapa saja yang ada di kelas Anda.
- **Widget Layar Utama**: Pantau jadwal kuliah Anda langsung dari layar utama perangkat Android Anda.
- **Lupa Kata Sandi**: Kemudahan memulihkan kata sandi akun Anda.

## 🛠️ Teknologi

EsaGo dibangun menggunakan [Flutter](https://flutter.dev), toolkit UI modern dari Google untuk membuat aplikasi yang indah dan dikompilasi secara native untuk seluler, web, dan desktop dari satu basis kode.

### Ketergantungan Utama:
- **Provider**: Untuk manajemen state.
- **HTTP & Cookie Jar**: Untuk menangani sesi jaringan dengan server Siakad.
- **HTML**: Untuk mem-parsing konten HTML yang diambil dari situs web.
- **Home Widget**: Untuk menyediakan widget di layar utama Android.
- **Shared Preferences**: Untuk menyimpan data sederhana di perangkat.
- **Intl**: Untuk keperluan internasionalisasi dan pemformatan.

## 🏁 Memulai

Untuk menjalankan proyek ini secara lokal, ikuti langkah-langkah berikut:

1.  **Prasyarat**: Pastikan Anda telah menginstal [Flutter SDK](https://flutter.dev/docs/get-started/install).
2.  **Klon Repositori**:
    ```bash
    git clone https://github.com/username/esago.git
    cd esago
    ```
3.  **Instal Ketergantungan**:
    ```bash
    flutter pub get
    ```
4
.  **Jalankan Aplikasi**:
    ```bash
    flutter run
    ```
