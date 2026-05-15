# Alpen AI Camera - Development Plan

Dokumen ini menyesuaikan roadmap dengan dua hal:
- arah produk di `README.md`: AI pose assistant + image processing real-time
- kondisi codebase saat ini: UI kamera sudah maju, tetapi wiring arsitektur dan fitur AI inti masih belum terimplementasi

## Arah Produk

Target produk tetap:
- aplikasi kamera Flutter dengan pengalaman kamera yang nyaman dipakai
- panduan pose real-time berbasis pose estimation
- feedback komposisi/pencahayaan yang proaktif

Urutan pengerjaan harus realistis:
- stabilkan kamera dulu
- bangun pipeline frame processing
- baru masuk ke AI pose real-time

Kalau urutannya dibalik, repo akan cepat penuh stub dan sulit diverifikasi.

## Kondisi Saat Ini

Yang sudah ada:
- `CameraHomeScreen` sudah punya UI kamera yang kaya: zoom ruler, filter carousel, flash, HDR, rasio aspek, mode kamera, shutter, dan switch camera
- plugin `camera` dan `gal` sudah dipakai langsung dari UI
- filter live sederhana sudah jalan lewat `FilterApplier`
- struktur Clean Architecture sudah dibuka di `domain`, `data`, dan `presentation`

Yang belum ada atau belum selesai:
- service inti masih stub: `CameraServiceImpl`, `PoseDetectorServiceImpl`, `PoseTemplateBuilderServiceImpl`, beberapa use case, dan `PoseScoreCalculator`
- state kamera masih menumpuk di satu screen, belum benar-benar dipindah ke controller/service
- belum ada dependency untuk storage lokal pose template, image picker/upload, atau runtime ML di `pubspec.yaml`
- test coverage masih sangat tipis dan baru menyentuh `FilterApplier`
- analyzer masih belum bersih

Kesimpulan praktis:
- repo ini belum masuk tahap “tambah banyak fitur”
- repo ini masih di tahap “rapikan fondasi dan pilih MVP yang bisa dituntaskan”

## MVP Yang Disarankan

MVP v1 sebaiknya dipersempit menjadi:
- live camera preview stabil
- capture ke galeri stabil
- filter live stabil
- image stream tersedia untuk frame processing
- satu template pose bawaan
- pose matching real-time sederhana
- ghost overlay + skor kecocokan + indikator siap foto

Yang belum perlu masuk MVP:
- HDR sungguhan di level device
- document scanner
- cloud sync
- banyak mode kamera palsu tanpa implementasi perilaku
- analisis komposisi yang terlalu luas sekaligus

## Roadmap

## Fase 0 - Scope Lock & Tech Decisions

Tujuan:
- mengunci keputusan teknis sebelum implementasi fitur AI dimulai

Checklist:
- [ ] Tetapkan MVP final seperti daftar di atas
- [ ] Pilih state management yang dipakai: tetap `ChangeNotifier` atau pindah ke solusi lain
- [ ] Pilih stack pose detection: TFLite / Google ML Kit / plugin lain
- [ ] Pilih local storage untuk template pose: Hive lebih cocok untuk offline-first sederhana
- [ ] Tentukan strategi input template: asset bawaan dulu atau upload dari galeri sejak awal

Output fase ini:
- keputusan dependency jelas
- backlog tidak bercampur antara eksperimen dan core delivery

## Fase 1 - Stabilize Camera App Core

Tujuan:
- menjadikan pengalaman kamera saat ini stabil dan mudah dirawat

Checklist:
- [ ] Bersihkan issue `flutter analyze`
- [ ] Pecah `CameraHomeScreen` menjadi widget yang lebih kecil
- [ ] Pindahkan lifecycle kamera, capture, flash, zoom, dan error state ke `presentation/controllers` + `data/services_impl`
- [ ] Definisikan kontrak `CameraService` yang lebih lengkap daripada `initialize()` dan `dispose()`
- [ ] Tambahkan state eksplisit: loading, ready, capturing, error
- [ ] Rapikan flow timer capture dan feedback ke user

Acceptance criteria:
- layar utama tidak menjadi pusat semua logika
- fitur kamera yang sudah ada tetap jalan setelah refactor
- analyzer bersih atau tinggal issue yang memang sengaja ditunda

## Fase 2 - Frame Processing Foundation

Tujuan:
- menyiapkan jalur aman untuk memproses frame kamera tanpa merusak performa UI

Checklist:
- [ ] Aktifkan `startImageStream` lewat service/controller, bukan langsung di UI
- [ ] Bentuk model payload frame yang konsisten untuk layer domain/data
- [ ] Implement `ImagePreprocessorDataSource` untuk konversi format frame
- [ ] Tambahkan throttling frame supaya inferensi tidak jalan di semua frame
- [ ] Pindahkan preprocessing berat ke isolate jika memang terbukti perlu

Acceptance criteria:
- app bisa menerima frame stream secara kontinu
- frame bisa diproses tanpa membuat preview terasa patah

## Fase 3 - Pose Detection MVP

Tujuan:
- menghadirkan fitur utama yang dijanjikan README dalam bentuk minimal tapi nyata

Checklist:
- [ ] Tambahkan dependency ML yang dipilih di Fase 0
- [ ] Implement `PoseDetectorDataSource`
- [ ] Implement `PoseDetectorServiceImpl.detectFromBytes`
- [ ] Selesaikan `AnalyzeLivePoseUseCase`
- [ ] Selesaikan `PoseScoreCalculator.calculate`
- [ ] Sediakan minimal satu pose template referensi bawaan

Acceptance criteria:
- dari frame kamera, sistem bisa menghasilkan landmark pose
- landmark bisa dibandingkan dengan template dan menghasilkan skor yang stabil

## Fase 4 - Ghost Overlay & Real-Time Feedback

Tujuan:
- menerjemahkan hasil AI ke UX yang benar-benar membantu user

Checklist:
- [ ] Buat `CustomPainter` untuk ghost overlay template
- [ ] Buat painter untuk skeleton user
- [ ] Tampilkan skor kecocokan dan status visual merah -> kuning -> hijau
- [ ] Tambahkan ambang “pose siap ditangkap”
- [ ] Jika perlu, aktifkan auto-capture saat skor konsisten di atas threshold beberapa frame

Acceptance criteria:
- user bisa melihat pose target dan posisi tubuhnya sendiri
- feedback yang muncul cukup stabil untuk diikuti, bukan flicker acak

## Fase 5 - Template Management

Tujuan:
- membuat sistem pose template bisa dipakai ulang, bukan demo satu pose saja

Checklist:
- [ ] Tambahkan local datasource untuk pose template
- [ ] Simpan metadata template + landmark hasil ekstraksi
- [ ] Implement `BuildPoseTemplateFromUploadUseCase`
- [ ] Tambahkan flow import gambar dari galeri
- [ ] Tampilkan daftar template yang bisa dipilih di UI

Acceptance criteria:
- user bisa memakai lebih dari satu template
- template tidak hilang saat app ditutup

## Fase 6 - Composition & Lighting Feedback

Tujuan:
- menambahkan fitur pendukung yang masih satu jalur dengan “smart photography assistant”

Checklist:
- [ ] Implement deteksi backlight sederhana berbasis luminance/histogram
- [ ] Tampilkan warning yang ringkas dan actionable
- [ ] Evaluasi apakah rule-of-thirds feedback cukup berguna atau hanya ornamental

Catatan:
- fase ini sebaiknya dikerjakan setelah pose MVP hidup
- jangan mengerjakan terlalu banyak analisis frame paralel sebelum performa terukur

## Fase 7 - Stretch Goals

Masuk sini hanya jika Fase 1-6 sudah stabil:
- [ ] document scanner
- [ ] perspective correction
- [ ] cloud sync template
- [ ] mode kamera tambahan yang benar-benar punya perilaku unik

## Prioritas Eksekusi Berikutnya

Urutan kerja paling sehat dari kondisi repo sekarang:
1. Bersihkan analyzer dan refactor `CameraHomeScreen`
2. Wire `CameraService` + `CameraController` sampai fitur kamera existing tetap jalan
3. Bangun image stream pipeline
4. Pilih dan integrasikan pose detector
5. Implement ghost overlay + pose scoring
6. Tambahkan template management

## Sprint Berikutnya Yang Paling Masuk Akal

Kalau mau dijadikan target kerja terdekat, sprint berikutnya sebaiknya hanya fokus ke ini:
- [ ] refactor `CameraHomeScreen` agar logika kamera tidak menumpuk di satu file
- [ ] perluas `CameraService` dan implementasi dasarnya
- [ ] bersihkan issue analyzer
- [ ] siapkan baseline test untuk controller/service kamera
- [ ] putuskan dependency ML dan storage yang akan dipakai

Jika sprint ini selesai, repo akan siap masuk ke fitur AI yang benar-benar bisa dikirim, bukan sekadar scaffold.
