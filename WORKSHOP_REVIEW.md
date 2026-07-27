# Review: Personalisasi Agen Cursor

Review menyeluruh untuk materi workshop tatap muka berdurasi 60 menit tentang kustomisasi Cursor coding agent.

## Kesimpulan Utama

Materi memiliki gagasan utama yang kuat dan urutan yang tepat—**Rules → Skills → Hooks**—tetapi belum cukup andal sebagai workshop praktik 60 menit.

Dalam bentuk saat ini, estimasi durasinya lebih mendekati:

- **85–110 menit** tanpa bagian bonus
- **100–130 menit** dengan Subagent dan Marketplace

Masalah dengan prioritas tertinggi:

1. Peserta belum memperoleh starter application yang dapat dijalankan dan direproduksi.
2. Beberapa latihan bergantung pada prompt nondeterministik tanpa kriteria keberhasilan.
3. Contoh Hooks memiliki dua kesalahan teknis kritis.
4. Contoh Skills belum berupa skill yang valid dan dapat diinstal.
5. Agenda tidak menyediakan waktu realistis untuk eksekusi agent, debugging, dan pertanyaan.

Materi tidak membutuhkan lebih banyak konsep. Materi membutuhkan **pengurangan scope, latihan deterministik, sintaks Cursor terbaru, dan checkpoint eksplisit**.

Satu hasil belajar utama yang disarankan:

> Peserta dapat memilih kapan menggunakan Rule, Skill, atau Hook, lalu membuat satu Rule dan satu Hook yang dapat diverifikasi.

---

## Hal yang Sudah Kuat

- Pembuka mengangkat masalah yang relevan: output coding agent bervariasi ketika ekspektasi tidak didefinisikan dengan jelas.
- Urutan materi tepat secara pedagogis:
  - **Rules** menyediakan konteks proyek yang persisten.
  - **Skills** menyediakan prosedur yang dapat digunakan kembali.
  - **Hooks** menegakkan perilaku secara deterministik.
- Penggunaan satu aplikasi tanggal dan waktu menciptakan kesinambungan antarbagian.
- Contoh Hooks sangat baik untuk menunjukkan perbedaan antara “memberi instruksi kepada model” dan “menegakkan perilaku.”
- Nada tulisan komunikatif dan sesuai untuk audiens meetup.
- Materi sudah mengingatkan tentang biaya context window dan risiko dependensi pihak ketiga.
- Screenshot dapat menjadi fallback ketika live agent menghasilkan sesuatu yang berbeda.
- Penutup kembali menguatkan tesis dari bagian pembuka.

---

## P0 — Wajib Diperbaiki Sebelum Workshop

### 1. Belum Ada Starter Project yang Dapat Dijalankan

Peserta diminta meng-clone repositori, tetapi repositori hanya berisi `README.org` dan aset gambar. Bagian selanjutnya mengasumsikan aplikasi Astro sudah tersedia:

- Instruksi clone: `README.org` baris 27–34
- Project Rule pertama: baris 137–150
- Latihan testing: baris 169–186
- “Aplikasi yang sudah kita buat”: baris 302–310

Peserta baru tidak dapat mereproduksi workshop hanya dari instruksi tertulis. Prompt pembuatan aplikasi di pembuka ditampilkan sebagai ilustrasi, bukan sebagai langkah praktik yang jelas.

**Perbaikan yang disarankan:** sediakan branch atau tag starter yang berisi:

- aplikasi Astro + TypeScript;
- `package.json` dan lockfile;
- versi Node yang diketahui;
- Vitest yang sudah dikonfigurasi;
- instruksi `npm install`, `npm run dev`, dan `npm test`;
- checkpoint seperti `workshop-start`, `after-rules`, dan `after-skills`;
- perintah reset untuk setiap latihan.

Jangan gunakan waktu workshop untuk menghasilkan baseline application. Hal itu akan menghabiskan banyak waktu dan membuat kondisi proyek setiap peserta berbeda.

### 2. Materi Tidak Muat dalam 60 Menit

Agenda mengalokasikan 55 menit sebelum menghitung bagian bonus:

| Bagian | Durasi di naskah |
|---|---:|
| Pembuka | 5 menit |
| Rules | 20 menit |
| Skills | 10 menit |
| Hooks | 15 menit |
| Penutup | 5 menit |

Subagent dan Marketplace belum memiliki durasi. Pada saat yang sama, peserta dipersilakan menginterupsi kapan saja. Materi juga memuat beberapa agent run, pembuatan file, konfigurasi testing, `chmod`, pemeriksaan hasil, dan debugging.

Estimasi realistis:

| Materi | Estimasi realistis |
|---|---:|
| Pembuka dan mental model | 8–12 menit |
| Penjelasan Rules dan dua agent run | 23–35 menit |
| Penjelasan Skills dan latihan | 20–35 menit |
| Pembuatan dan pengujian Hooks | 16–25 menit |
| Rangkuman dan feedback | 5–7 menit |
| Setup, debugging, dan pertanyaan | 8–15 menit |

**Perbaikan yang disarankan:** gunakan satu latihan utama per mekanisme. Pindahkan Subagent, Marketplace, skill Tidy TDD lengkap, dan fitur zona waktu kedua menjadi materi bawa pulang.

### 3. Prompt `refactor` Terlalu Ambigu untuk Latihan Langsung

Naskah dengan tepat menjelaskan bahwa `refactor` adalah prompt ambigu, tetapi kemudian mengharapkan Rules membuat prompt tersebut cukup jelas.

Rules yang menentukan Astro, TypeScript, warna, dan aksesibilitas tetap tidak menjelaskan:

- bagian apa yang harus direfaktor;
- perilaku apa yang harus dipertahankan;
- file apa yang boleh diubah;
- tes apa yang membuktikan keberhasilan;
- kapan agent harus berhenti.

Cursor dapat meminta klarifikasi, mengubah kode yang tidak berkaitan, atau tidak melakukan perubahan. Menjalankan `refactor` untuk kedua kalinya juga tidak otomatis berarti “tambahkan testing.”

**Perbaikan yang disarankan:** pertahankan `refactor` hanya sebagai demonstrasi singkat tentang ambiguitas. Untuk latihan peserta, gunakan tugas yang dibatasi dengan jelas:

> Refactor logika format tanggal dari komponen UI menjadi fungsi murni `formatIndonesiaTime(date, timeZone)`. Jangan ubah tampilan. Tambahkan tes menggunakan konfigurasi Vitest yang sudah tersedia, jalankan tes, lalu berhenti.

Untuk setiap latihan, tentukan:

- checkpoint awal;
- prompt lengkap;
- file yang diharapkan berubah;
- kriteria keberhasilan;
- perintah verifikasi;
- timebox;
- perintah reset;
- fallback jika peserta tertinggal.

### 4. Contoh Hook Menggunakan Nama Field yang Salah

Script saat ini menghasilkan:

```json
{
  "permission": "deny",
  "agentMessage": "Blocked: ..."
}
```

Schema Hooks Cursor menggunakan snake case:

```json
{
  "permission": "deny",
  "user_message": "Dependency installation was blocked.",
  "agent_message": "Use existing packages or Intl.DateTimeFormat."
}
```

`agentMessage` bukan field yang terdokumentasi, sehingga panduan tersebut mungkin tidak diteruskan kepada agent.

Referensi: [Cursor Hooks documentation](https://cursor.com/docs/hooks#beforeshellexecution-beforemcpexecution).

### 5. Hook Bersifat Fail-Open Secara Default

Naskah mengatakan output JSON yang tidak valid atau exit non-zero mungkin akan memblokir aksi. Perilaku Cursor saat ini lebih spesifik:

- exit `0`: gunakan response JSON;
- exit `2`: blokir aksi;
- exit lainnya: Hook gagal dan aksi dilanjutkan;
- crash, timeout, atau JSON tidak valid: aksi dilanjutkan secara default.

Untuk guard Hook, gunakan:

```json
{
  "command": ".cursor/hooks/guard-npm.sh",
  "failClosed": true
}
```

Tanpa `failClosed: true`, kesalahan parser dapat mengizinkan perintah yang seharusnya diblokir.

Referensi: [Cursor command-based hooks](https://cursor.com/docs/hooks#command-based-hooks).

### 6. Parser JSON pada Hook Terlalu Rapuh

Script mengekstrak command menggunakan:

```bash
grep -o '"command":"[^"]*"'
```

Pola tersebut gagal untuk JSON valid yang memiliki spasi:

```json
{"command": "npm install moment"}
```

Pola juga tidak menangani karakter escape dengan aman. Jika digabungkan dengan perilaku fail-open, kegagalan parsing dapat melewati guard.

Contoh resmi Cursor menggunakan `jq`:

```bash
command=$(echo "$input" | jq -r '.command // empty')
```

Jika menggunakan `jq`, tambahkan ke daftar prasyarat dan verifikasi sebelum workshop.

Hook ini juga sebaiknya disebut sebagai **workshop guardrail**, bukan security boundary. Alias shell, script lain, syntax alternatif, atau pengeditan langsung `package.json` dapat melewati pencocokan string.

### 7. Contoh Tidy TDD Belum Menjadi Skill yang Valid

Naskah menampilkan blok Markdown panjang sebagai Skill, tetapi Cursor membutuhkan folder yang berisi `SKILL.md` dengan YAML frontmatter:

```text
.agents/
└── skills/
    └── tidy-tdd/
        └── SKILL.md
```

```markdown
---
name: tidy-tdd
description: Use test-driven development and Tidy First when implementing or changing behavior.
---

# Tidy TDD

...
```

Naskah belum menjelaskan:

- directory yang harus dibuat;
- file yang harus dibuat;
- metadata minimum;
- cara memastikan Skill ditemukan;
- cara menjalankan Skill secara eksplisit.

Pemanggilan eksplisit yang terdokumentasi adalah `/tidy-tdd` melalui slash menu.

Referensi: [Cursor Agent Skills documentation](https://cursor.com/docs/skills#skillmd-file-format).

---

## P1 — Koreksi Materi dan Kurikulum

### 1. Perbaiki Terminologi dan Perilaku Rules

Naskah mengatakan ada empat mode, tetapi hanya mencantumkan tiga. Daftar yang lengkap:

1. **Always Apply**
2. **Apply Intelligently**
3. **Apply to Specific Files**
4. **Apply Manually**

Manual Rule dipanggil dengan menyebut Rule tertentu, misalnya `@project-rules`, bukan `@rules` generik.

Property frontmatter juga bernama `globs`, bukan `glob`:

```yaml
---
globs: "src/**/*.tsx"
alwaysApply: false
---
```

Referensi: [Cursor Rules documentation](https://cursor.com/docs/rules#rule-anatomy).

Definisi Rules di glosarium yang mengatakan Rules selalu dimasukkan ke setiap prompt juga tidak tepat. Hanya Always Apply Rule yang selalu disertakan. Rule lain bergantung pada relevansi, file yang cocok, atau mention eksplisit.

### 2. Bedakan Fakta Dokumentasi dari Rekomendasi Pribadi

Naskah menyarankan Rule dipecah setelah kira-kira 100 baris. Rekomendasi resmi Cursor saat ini adalah menjaga setiap Rule di bawah 500 baris.

Rekomendasi 100 baris tetap masuk akal, tetapi tandai sebagai preferensi fasilitator:

> Untuk workshop ini, saya menyarankan Rule tetap di bawah sekitar 100 baris agar mudah dibaca dan ditinjau. Dokumentasi Cursor saat ini menyarankan setiap Rule tetap di bawah 500 baris.

Klaim bahwa Cursor otomatis memangkas Rule berprioritas rendah ketika context penuh juga tidak terdokumentasi. Hindari menjanjikan algoritma truncation tertentu.

### 3. Jadikan Learning Objectives Dapat Diamati

“Memahami dan mengerti” tidak dapat diukur. Gunakan hasil belajar berbasis tindakan:

> Di akhir sesi, peserta dapat:
>
> 1. menjelaskan perbedaan Rule, Skill, dan Hook;
> 2. membuat dan memverifikasi satu Project Rule;
> 3. menjalankan satu Skill secara eksplisit;
> 4. membuat Hook yang memblokir perintah tertentu;
> 5. memilih mekanisme yang tepat untuk kebutuhan proyek.

### 4. Tambahkan Decision Framework

Materi menjelaskan setiap mekanisme secara terpisah, tetapi belum memberikan cara sederhana untuk memilih mekanisme yang tepat.

Tambahkan tabel berikut dekat bagian awal dan gunakan kembali setelah setiap latihan:

| Mekanisme | Digunakan untuk | Contoh |
|---|---|---|
| Rule | Konteks dan batasan proyek yang persisten | Gunakan Astro; ikuti konvensi arsitektur |
| Skill | Workflow atau keahlian yang dapat digunakan kembali | TDD, deployment, UI review |
| Hook | Enforcement dan otomatisasi deterministik | Blokir dependency install; jalankan formatter |

Pertanyaan fasilitator yang dapat diulang:

> Mengapa kebutuhan ini sebaiknya menjadi Rule, Skill, atau Hook—bukan yang lainnya?

### 5. Kurangi Bagian Skills Secara Signifikan

Slot Skills hanya sepuluh menit, tetapi mencakup:

- konsep Skill;
- beberapa lokasi instalasi;
- panduan TDD/Tidy First lebih dari 60 baris;
- commit discipline;
- code-quality principles;
- dua fitur aplikasi;
- dua koleksi Skill eksternal.

Gunakan Skill 10–15 baris dengan satu perilaku yang dapat diamati untuk sesi langsung. Jadikan versi Tidy TDD lengkap sebagai materi bawa pulang.

Naskah juga mengatakan “tiga fitur baru,” sementara hanya dua latihan fitur yang aktif. Ubah menjadi “dua fitur utama dan satu latihan bonus,” atau sisakan satu fitur utama untuk workshop.

### 6. Buat Prompt Zona Waktu Lebih Presisi

“Tiga bagian waktu Indonesia” sebaiknya menjadi “tiga zona waktu Indonesia.” Tambahkan singkatan WIT dan gunakan identifier IANA untuk mencegah hasil berbeda berdasarkan locale komputer:

- `Asia/Jakarta` — WIB
- `Asia/Makassar` — WITA
- `Asia/Jayapura` — WIT

Tentukan juga format keluaran dan interval pembaruan.

### 7. Uji Hook Secara Deterministik Sebelum Menggunakan Agent

Naskah menyarankan pengujian script secara terpisah, tetapi belum memberikan command.

Uji jalur deny:

```bash
printf '%s\n' '{"command":"npm install moment"}' \
  | .cursor/hooks/guard-npm.sh
```

Expected response:

```json
{
  "permission": "deny",
  "user_message": "Dependency installation was blocked.",
  "agent_message": "Use Intl.DateTimeFormat instead."
}
```

Kemudian uji jalur allow:

```bash
printf '%s\n' '{"command":"npm test"}' \
  | .cursor/hooks/guard-npm.sh
```

Setelah kedua jalur berhasil, baru trigger Hook melalui Cursor.

Pesan penting untuk peserta:

- pilihan aksi agent bersifat nondeterministik;
- perilaku Hook harus deterministik.

### 8. Perbaiki Kontradiksi Kebijakan Dependensi

Guard memblokir instalasi semua dependency, tetapi catatan merekomendasikan `date-fns` atau `Intl.DateTimeFormat`. `date-fns` juga merupakan dependency eksternal.

Untuk latihan ini, rekomendasikan hanya `Intl.DateTimeFormat`. Sebutkan `date-fns` hanya sebagai opsi ketika kebijakan proyek mengizinkan dependency tambahan.

### 9. Perbarui Instruksi dan Screenshot UI

Screenshot Rules menampilkan pesan bahwa “Rules, Skills, Subagents are moving to Customize,” sedangkan naskah mengarahkan peserta ke Settings dan `+ New Rule`.

Alur dokumentasi saat ini:

> Customize → Rules → Add Rule

Screenshot Skills hanya menampilkan empty state “No Skills Yet.” Screenshot tersebut belum membuktikan Skill berhasil dibuat atau ditemukan.

Ganti dengan screenshot yang menunjukkan:

- `tidy-tdd` terdaftar di Skills;
- file `SKILL.md` yang sesuai;
- `/tidy-tdd` terlihat di slash menu.

---

## Rekomendasi Agenda 60 Menit

| Waktu | Aktivitas |
|---:|---|
| 0–5 | Masalah, hasil belajar, dan readiness check |
| 5–10 | Decision framework Rule vs Skill vs Hook |
| 10–24 | Buat satu Rule dan jalankan satu tugas before/after |
| 24–32 | Demonstrasikan satu Skill pendek yang sudah disiapkan |
| 32–47 | Salin, uji, dan trigger satu Hook |
| 47–52 | Troubleshooting dan safety caveats |
| 52–57 | Latihan memilih mekanisme untuk tiga skenario |
| 57–60 | Rangkuman dan feedback |

Pindahkan seluruh bagian berikut menjadi materi bawa pulang:

- Skill Tidy TDD lengkap;
- fitur kota populer;
- Subagent;
- Marketplace;
- koleksi community Skills.

Jika seluruh praktik saat ini harus dipertahankan, ubah label workshop menjadi **90–120 menit**.

---

## Template Latihan yang Konsisten

Setiap praktik sebaiknya memakai struktur yang sama:

```text
Goal:
Timebox:
Starting checkpoint:
Participant steps:
Expected files changed:
How to verify:
Expected result:
If blocked:
How to reset:
```

Contoh:

> **Goal:** Membuktikan Hook dapat memblokir instalasi dependensi.  
> **Timebox:** 10 menit.  
> **Starting checkpoint:** `git switch --detach workshop-hooks`.  
> **Success:** Payload `npm install moment` menghasilkan `permission: deny`; `npm test` menghasilkan `permission: allow`.  
> **If blocked:** Berpasangan dengan peserta di sebelah atau ikuti demo fasilitator.  
> **Reset:** Hapus entri Hook atau jalankan `git restore .cursor`.

Format tersebut akan membuat materi dapat digunakan oleh fasilitator selain penulisnya.

---

## Fasilitasi dan Aksesibilitas

### 1. Gunakan Checkpoint Pertanyaan

“Silakan interupsi kapan saja” bertentangan dengan jadwal yang sudah padat.

Alternatif yang lebih terkontrol:

> Pertanyaan yang menghalangi praktik boleh langsung disampaikan. Pertanyaan konseptual akan kita bahas pada checkpoint setelah Rules, Skills, dan Hooks. Pertanyaan lain dapat dikirim melalui QR.

Tambahkan dua question buffer singkat ke agenda.

### 2. Tambahkan URL Teks untuk QR Pertanyaan

QR pertanyaan tidak memiliki URL yang dapat dibaca manusia. Tambahkan:

- URL singkat;
- nama platform tujuan;
- kegunaan QR;
- instruksi singkat.

Bagian feedback sudah lebih baik karena menyertakan URL teks.

### 3. Berikan Observation Prompt untuk Screenshot

Banyak screenshot belum memiliki caption yang menjelaskan apa yang perlu diperhatikan. Sebagian besar UI juga terlalu kecil untuk dibaca dari belakang ruangan.

Gunakan caption yang menyatakan bukti spesifik, misalnya:

> Perhatikan bahwa Agent membuat fungsi murni terpisah dan menjalankan sembilan tes.

Crop screenshot agar hanya menampilkan area UI yang relevan.

### 4. Periksa Penggunaan Ulang `demo-2.png`

`demo-2.png` digunakan pada bagian Rules dan Subagent. Kemungkinan salah satu penggunaan tidak tepat atau setidaknya belum dijelaskan.

### 5. Tentukan Fungsi Instruksional Trinity Frames

Tujuh frame gambar ditampilkan berturut-turut tanpa caption atau pertanyaan observasi. Gunakan GIF satu kali dengan penjelasan yang jelas, atau hapus jika hanya bersifat dekoratif.

### 6. Bedakan Instruksi Peserta dan Cue Fasilitator

Gunakan label konsisten:

- **Fasilitator**
- **Peserta**
- **Hasil yang diharapkan**
- **Jika gagal**
- **Contoh saja—jangan dijalankan**

### 7. Sediakan Jalur untuk Peserta yang Tertinggal

Tambahkan:

- checkpoint angkat tangan atau status warna;
- opsi berpasangan;
- branch hasil akhir per tahap;
- izin eksplisit untuk mengikuti demo tanpa mengetik;
- screenshot atau rekaman fallback untuk setiap live demo.

---

## Koreksi Bahasa dan Konsistensi

Lakukan copy-editing setelah perubahan struktur selesai. Koreksi utama:

- “memahami dan mengerti” → “memahami”
- “Menggunakkan” → “Menggunakan”
- “siapin” → “menyiapkan”
- “install” → “instal”, atau gunakan istilah Inggris secara konsisten
- “login” → “masuk”
- “Clone repo” → “Klon repositori”
- “coding standard” → “standar penulisan kode”
- “di refactor” → “direfaktor”
- “bebersih” → “pembersihan”
- “berebahaya” → “berbahaya”
- “analisa” → “analisis”
- “zona waktu nya” → “zona waktunya”
- “Waktu Indonesia Timur” → “Waktu Indonesia Timur (WIT)”
- “until everything clear” → “until everything is clear”
- “browse dan install” → “menelusuri dan menginstal”
- “Non Deterministic” → “Nondeterministik”
- “Vitest: Tools” → “Vitest: alat”

Standarkan pemakaian istilah berikut di seluruh dokumen:

- `agent` atau `agen`;
- `test` atau `tes`;
- `rule` atau `aturan`;
- `workflow` atau `alur kerja`;
- sapaan “kita”, “peserta/Anda”, dan “fasilitator/saya”.

Glosarium juga memuat konsep yang tidak digunakan dalam workshop—Milestone, Piramida Berpikir, PRD, SPEC, Slices, dan User Stories. Hapus entri tersebut kecuali konsepnya dikembalikan ke isi utama.

---

## Urutan Revisi yang Disarankan

1. Tentukan apakah workshop harus tepat 60 menit atau dapat diperpanjang menjadi 90–120 menit.
2. Tambahkan starter project dan checkpoint yang dapat direproduksi.
3. Koreksi sintaks Rules, Skills, dan Hooks.
4. Tulis ulang latihan dengan verifikasi dan recovery path.
5. Kurangi bagian Skills untuk sesi langsung.
6. Tambahkan decision framework Rule/Skill/Hook.
7. Perbarui screenshot dan fallback QR.
8. Lakukan copy-editing bahasa Indonesia.
9. Lakukan rehearsal dari clean machine dan ukur setiap agent run.
10. Siapkan screenshot atau rekaman fallback untuk setiap live demo.

Dengan perubahan tersebut, materi dapat menjadi workshop 60 menit yang efektif. Fondasi konseptualnya sudah baik; pekerjaan utama berikutnya adalah membuat eksekusinya **terbatas, terkini, dapat diverifikasi, dan dapat direproduksi**.
