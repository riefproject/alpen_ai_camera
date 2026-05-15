# 📸 Alpen AI Camera: Smart Photography Assistant

## 📖 Ringkasan Eksekutif

**Alpen AI Camera** adalah aplikasi kamera cerdas berbasis Flutter yang mengintegrasikan *Artificial Intelligence* (AI Pose Estimation) dan *Digital Image Processing* (DIP). Aplikasi ini bertindak sebagai "asisten fotografer virtual" yang memberikan panduan pose secara *real-time* dan melakukan koreksi komposisi citra interaktif untuk membantu pengguna awam menghasilkan foto yang estetik dan proporsional.

## 🚨 Latar Belakang & Permasalahan

Dalam fotografi kasual, banyak pengguna menghadapi dua kendala utama:

1. **Photogenic Anxiety (Kaku Berpose):** Kebingungan menempatkan postur tubuh yang natural di depan kamera, sehingga hasil foto sering kali terlihat kaku atau canggung.
2. **Kurangnya Pemahaman Komposisi Dasar:** Ketidakmampuan membaca kondisi pencahayaan (seperti *backlight*) atau menempatkan subjek dalam *frame* (seperti *Rule of Thirds*), yang sering kali merusak kualitas citra meski diambil dengan kamera resolusi tinggi.

Sewa fotografer profesional untuk kebutuhan sederhana tentu tidak efisien. Di sinilah Alpen AI Camera hadir untuk menjembatani kesenjangan tersebut.

## 💡 Solusi yang Ditawarkan

Alpen AI Camera menyelesaikan permasalahan di atas melalui antarmuka kamera yang interaktif dan *real-time*:

* **Sistem Pemandu Pose Visual:** Alih-alih menebak gaya, pengguna cukup mengikuti *Ghost Overlay* (siluet pose referensi) di layar. AI akan melacak sendi tubuh pengguna dan memberikan umpan balik langsung hingga pose pengguna sejajar dengan referensi.
* **Analisis Citra Proaktif:** Sistem memproses *frame* mentah dari kamera untuk mendeteksi anomali pencahayaan atau komposisi yang buruk, lalu memberikan instruksi korektif sebelum tombol *shutter* ditekan.

## ✨ Fitur Utama

### 1. Real-Time Pose Recommendation

* **Ghost Overlay:** Menampilkan *outline* transparan dari pose referensi terpilih langsung di atas layar (*Viewfinder*).
* **Dynamic Skeleton Tracking:** Melacak 33 titik sendi (bahu, siku, lutut, dll.) secara *real-time* dan menampilkan garis kerangka tubuh pengguna.
* **Match Scoring & Auto-Capture:** Menghitung tingkat kemiripan (menggunakan *Cosine Similarity*) antara postur pengguna dan referensi. Sistem akan memberikan indikator warna (Merah ke Hijau) dan dapat mengambil foto secara otomatis saat tingkat kemiripan mencapai ambang batas ideal (misal: $>90\%$).
* **Pose Template Builder:** Memungkinkan pengguna untuk mengekstrak pose dari foto di galeri dan menyimpannya sebagai template *overlay* baru.

### 2. Intelligent Composition & Lighting Feedback

* **Backlight Warning:** Menganalisis histogram citra untuk mendeteksi cahaya latar yang terlalu dominan dan memberikan peringatan teks interaktif (contoh: *"Cahaya latar terlalu terang, ubah posisi"*).
* **Smart Grid Lines:** Panduan *Rule of Thirds* dinamis yang membantu pengguna memosisikan subjek di titik fokus yang tepat.

### 3. Real-Time Image Processing (DIP)

* **Live Color Filters:** Filter warna instan (*Alami, Manis, Keriangan, Kristal*) menggunakan manipulasi matriks nilai piksel (RGB) tanpa mengorbankan *frame rate* (60 FPS).
* **Hardware-Safe Zoom:** Integrasi kontrol *zoom* jangka sorong yang memetakan rentang skala UI dengan batasan perangkat keras kamera secara aman.

### 4. Smart Document Scanner (Stretch Feature)

* Mode pemindai berbasis *Canny Edge Detection* untuk mendeteksi batas dokumen (kertas/papan tulis) dan menerapkan transformasi perspektif secara otomatis.

## 🛠 Teknologi Pendukung

* **Framework:** Flutter (Dart) dengan arsitektur *Clean Architecture* (Domain, Data, Presentation).
* **Vision & AI:** Model Machine Learning ringan (seperti TFLite / BlazePose) yang berjalan di *Background Isolate* untuk performa tinggi.
* **Digital Image Processing:** Algoritma pemrosesan citra murni dan interpolasi warna.
* **Penyimpanan:** Hive (Local Storage) untuk menyimpan *state* dan *template* pose.