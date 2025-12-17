------------------------------------------------------------------------------------------
[![License: Freeware Creditware](https://img.shields.io/badge/license-Freeware%20Creditware-brightgreen.svg?style=flat-square)]()
[![Author](https://img.shields.io/badge/Author-Raihan%20Purnawadi-blue.svg?style=flat-square)](https://github.com/RaihanPrnwd)
# INDOKU Smuggler System (Sistem Paket Penyelundupan)

---

## 🇮🇩 Penjelasan Sangat Lengkap (Bahasa Indonesia)

### Apa Itu Sistem Smuggler?

Sistem **Smuggler** adalah event otomatis di server *INDOKU ROLEPLAY* (SA-MP) yang menghadirkan pengalaman gameplay kompetitif baru: **perebutan paket penyelundupan**. Script ini sepenuhnya orisinil, dikembangkan oleh [Raihan Purnawadi](https://github.com/RaihanPrnwd), dan digunakan aktif di server INDOKU.

### Fitur Utama:

- **Event Otomatis Setiap 30 Menit**  
  Sistem akan memunculkan "paket penyelundupan" di lokasi random pada map setiap 30 menit, tanpa perlu campur tangan admin.

- **Rebutan Paket (SMUGGLER)**  
  Player berperan sebagai civilian atau polisi (on duty) dapat berlomba mengambil paket. EMS (Emergency/Paramedic) **tidak bisa ikut** dalam event.

- **Marker Emas & Blip Otomatis**  
  - Begitu paket muncul, lokasi terlihat di map (BLIP emas khusus) untuk seluruh pemain yang eligible.
  - Setelah diambil, carrier (pembawa paket) akan menjadi target seluruh server, ditandai marker emas melayang di atas kepala (pakai pickup dynamic & 3DText).

- **Wanted Level Maksimal**  
  Carrier langsung terdeteksi polisi/server dengan wanted level tertinggi.

- **Objektif**  
  Carrier harus mengantar paket ke _delivery point_ (koordinat finish) yang telah ditentukan. Jika berhasil, mendapatkan hadiah uang cash langsung ke character.

- **Risiko & Update Status**  
  - Jika carrier tewas atau disconnect, paket otomatis "jatuh" ke lokasi terakhir (terupdate), sehingga bisa direbut ulang oleh player lain.
  - Begitu paket drop, BLIP dan pickup akan diperbarui ke posisi baru, dan open kembali untuk berebut.

- **Timeout Event**  
  Jika tidak ada yang mengantar/menyelesaikan event dalam 1 jam, sistem otomatis menghanguskan event dan menunggu interval berikutnya.

- **Semua Logic Otomatis**  
  Blip, marker, eligible check, pickup, event reporting, hadiah, wanted level, drop logic, global message—all dihandle sistem tanpa intervensi manual.

### Siklus Event secara Singkat:

1. Setiap 30 menit, sistem memilih satu dari 6 titik random untuk spawn paket.
2. Semua player eligible dapat melihat BLIP paket di map, serta label 3D di atas paket.
3. Player pertama yang mendekat dan mengetik `/pickupsmuggler`, setelah animasi, akan menjadi carrier.
4. Semua player tahu siapa carrier (marker emas di kepala). Carrier harus survive hingga delivery point.
5. Player lain dapat menggagalkan upaya carrier dengan membunuh/membuat disconnect. Paket jatuh = event reset dengan posisi baru.
6. Jika carrier tiba di point penyerahan, mendapatkan hadiah cash (otomatis Creditbox).
7. Setelah event selesai, event cooldown selama 30 menit, lalu siklus terulang.

#### Spesifikasi Script Teknis:

- **Role Logic:**  
  - EMS tidak pernah eligible; polisi hanya saat on duty; civilian always eligible (selain EMS).
- **Kode Modular:**  
  Semua proses (BLIP, pickup, reward, drop) dipisahkan ke fungsi/foward tersendiri agar mudah integrasi di mode lain.
- **Safety:**  
  Prevent race-condition (pemain disconnect atau meninggal detik yang sama) dan update cleanup otomatis objek TEMP event.
- **Implementasi:**  
  Cukup panggil fungsi utama (lihat dokumentasi di script) dan integrasikan hook pada event (OnPlayerUpdate, OnPlayerConnect, dsb).
- **Pesan & Notifikasi:**  
  Semua notifikasi penting dikirim ke seluruh pemain, termasuk event mulai, paket berhasil, paket drop, timeout, dan cancel admin.

#### Saran & Pengujian

Script telah diuji dalam skenario player <-> player brutal yang sangat kompetitif. Tidak terdapat memory leak, blip error, atau pickup duplication. Penggunaan di server live dapat dicek dengan bergabung di **INDOKU ROLEPLAY**.

---

### 📢 **Mau Coba Sistem Ini?**

Bergabunglah ke server INDOKU ROLEPLAY—rasakan sendiri event Smuggler beserta semua fitur eksklusif lain secara langsung bersama komunitas kami!

---

## 🇬🇧 Full Detailed Explanation (English)

### About Smuggler System

The **Smuggler System** is an automated, competitive package event designed for the *INDOKU ROLEPLAY* server (SA-MP). This system was completely designed and implemented by [Raihan Purnawadi](https://github.com/RaihanPrnwd) and is actively running on INDOKU.

### Main Features:

- **Automated 30-Minute Event Cycle**  
  Every 30 minutes, the system spawns a "smuggler package" at a random pre-set location—no admin required.

- **For Cops & Civilians Only**  
  Only civilians and "on duty" police officers are eligible to compete for the package. EMS (paramedics) are never eligible.

- **Smart Map Blips & Gold Marker**  
  - All eligible players can see a gold blip on the map for the package spot.
  - When a package gets picked up, the carrier is visually marked for all with a floating gold pickup/label over their head (real dynamic 3D marker).

- **Automatic Maximum Wanted Level**  
  The carrier gets instantly set to max wanted & reported to the police.

- **Objective**  
  Carrier must reach a hidden delivery point. Succeeding gives them a direct cash reward.

- **Event Dynamics**  
  - If the carrier dies or disconnects, the package drops and becomes available again at the new position with refreshed pickups/blips.
  - Everyone can fight for the dropped package—the cycle continues until successful delivery or timeout.

- **Event Timeout**  
  If no one delivers the package within 1 hour, the event aborts and cooldown starts again.

- **Full Automatic Logic**  
  Everything from eligibility checking, pickup creation, blip/map management, reward logic, drop, admin-cancel, and messaging is automated.

### Event Walkthrough

1. Every 30 minutes, the package spawns at one of 6 possible places.
2. Eligible players see map BLIP and 3D label floating on the package.
3. The first player to `/pickupsmuggler` (close enough) gets an animation and claims the carrier role.
4. All others track the gold marker above the carrier—who must now deliver while surviving everyone!
5. If the carrier dies/disconnects, the package "drops"—position and blip update, event continues.
6. Delivering the package to the delivery point gives an instant cash reward (displayed in a reward box).
7. After the event, it enters a 30-minute cooldown before restarting.

#### Technical Script Details

- **Role Filtering:**  
  EMS is always filtered out, only police-on-duty and civilians participate.
- **Modular Code:**  
  All logic such as BLIP, pickup/marker, reward, and drop is functionally modular for easy GM integration.
- **Safety:**  
  Prevents race-conditions, duplicate pickups, and keeps server clean by destroying all temp objects promptly.
- **Message System:**  
  All important state changes are announced to all players (start, pickup, drop, success, timeout, admin cancel).

#### Testing & Live Demo

This script is stress-tested for multi-player concurrency. No memory leaks, blip artifacts, or pickup bugs occur under heavy stress. Try it yourself on the live **INDOKU ROLEPLAY** server!

---

### 📢 **Want to Try or See This Script Live?**

Join **INDOKU ROLEPLAY** and enjoy public Smuggler events and many custom features built for our community!

---


## License

MIT License

Copyright (c) Raihan Purnawadi

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.


---

Script original repository:  
https://github.com/RaihanPrnwd

------------------------------------------------------------------------------------------
