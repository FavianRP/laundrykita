# Smart Laundry POS & Automated Governance System
## Backend API Reference untuk Frontend Developer

Dokumen ini adalah referensi tunggal untuk integrasi antarmuka pengguna (Frontend) dengan backend FastAPI. Dokumen ini mencakup seluruh alur data, aturan bisnis, skema payload, dan batasan sistem yang wajib dipatuhi di sisi klien.

---

## 1. Environment & Setup Lokal

Pastikan backend berjalan sebelum memulai pengembangan frontend.

**Prasyarat:**
- Docker (untuk database MariaDB)
- Python 3.12+ dan `uv` (atau pip)

**Langkah Menjalankan:**
1. Jalankan database: `docker compose up -d` (Pastikan MariaDB berjalan di port `3306`).
2. Populate skema dan seed awal: `docker exec -i mariadb mariadb -u root -p<password> < db/init.sql`
3. Salin konfigurasi: `cp .env.example .env` (Sesuaikan credential DB jika perlu).
4. Install dependency: `pip install -r requirements.txt`
5. Jalankan server: `uvicorn main:app --reload --host 0.0.0.0 --port 8000`

**Akses Dokumentasi Interaktif:**
- Swagger UI: `http://localhost:8000/api/docs`
- ReDoc: `http://localhost:8000/api/redoc`

---

## 2. Base URL & Autentikasi

**Base URL:** `http://localhost:8000/api`

**Mekanisme Auth:**
Sistem menggunakan JWT (JSON Web Token). Semua endpoint yang memerlukan autentikasi wajib mengirim header:
```
Authorization: Bearer <access_token>
```

**Akun Default (Setelah Init DB):**
- Owner: `username: owner`, `password: owner123`
- Kasir: `username: kasir1`, `password: kasir123`

**Catatan Penting Token:**
- Token memiliki masa berlaku (Default: 480 menit / 8 jam).
- Jika mengembalikan `401 Unauthorized`, lakukan redirect ke halaman login dan hapus state token di sisi klien.
- Payload token berisi `sub` (user_id string) dan `role`.

---

## 3. Standar Respon & Penanganan Error

**Sukses (2xx):**
- **Tunggal:** Mengembalikan objek JSON langsung.
- **List/Paginasi:** Mengembalikan objek dengan struktur:
  ```json
  {
    "data": [...],
    "pagination": {
      "page": 1,
      "page_size": 20,
      "total": 100,
      "total_pages": 5
    }
  }
  ```

**Error (4xx / 5xx):**
Selalu mengembalikan objek dengan key `detail`:
```json
{
  "detail": "Pesan error spesifik dari backend dalam Bahasa Indonesia."
}
```
*Kode HTTP yang sering muncul:*
- `401`: Token tidak valid, expired, atau tidak dikirim.
- `403`: Role pengguna tidak diizinkan mengakses endpoint.
- `404`: Resource (Order, Customer, Edit Request) tidak ditemukan.
- `409`: Data duplikat (Contoh: Nomor telepon atau username sudah terdaftar).
- `422`: Pelanggaran aturan bisnis (Contoh: Status produksi mencoba mundur, ada pending request lain).

---

## 4. Aturan Bisnis Inti (Wajib Diterapkan di Frontend)

Frontend bertanggung jawab memastikan UI mencerminkan aturan bisnis berikut. Jangan hanya mengandalkan error dari backend.

### 4.1 Database-Driven Immutability (Hard Lock)
- Setiap order yang berhasil dibuat **LANGSUNG** terkunci (`is_locked: true`).
- Frontend **WAJIB** menonaktifkan semua input field (disabled) pada detail pesanan jika `is_locked` bernilai `true`.
- Tidak ada endpoint untuk mengedit data finansial order secara langsung.

### 4.2 State Machine Status Produksi
Status hanya bisa maju, tidak boleh mundur.
`Antrean` -> `Dicuci` -> `Disetrika` -> `Siap Diambil` -> `Selesai`
- Jika status saat ini `Dicuci`, tombol untuk mengubah ke `Antrean` harus di-hidden atau di-disable di UI.

### 4.3 Alur Koreksi Data (Edit Request)
Jika kasir salah input dan ingin mengubah data yang sudah terkunci:
1. Kasir membuka modal/form "Ajukan Perbaikan".
2. Kasir mengisi alasan dan data baru.
3. Data dikirim ke endpoint `POST /api/edit-requests`.
4. Status order tetap terkunci. Di UI kasir, tampilkan badge "Menunggu Persetujuan Owner".
5. Owner melihat perubahan (tampilan Git-Diff) di dashboard mereka.
6. Jika owner approve, data di backend otomatis berubah dan order tetap terkunci.

### 4.4 Soft Cancel (Pembatalan Lunak)
- Order **TIDAK PERNAH** di-delete dari database.
- Pembatalan dilakukan via `POST /api/edit-requests/cancel`.
- Jika owner approve, flag `is_cancelled` berubah menjadi `true`.
- **Efek di UI:**
  - Halaman list order default: Order batal **tidak ditampilkan**.
  - Halaman list order (dengan filter `include_cancelled=true`): Order batal ditampilkan dengan badge/label "Dibatalkan".
  - Halaman Tracking Publik: Menampilkan status "Dibatalkan" dan progress `-1`.
  - Halaman Analytics/Laporan: Order batal **dikecualikan** dari seluruh kalkulasi pendapatan.

### 4.5 Historical Price Preservation
- Nilai `price_per_unit` yang tersimpan di `order_items` adalah harga saat transaksi terjadi.
- Jika owner mengubah harga layanan di masa depan, harga di invoice/order lama **tidak berubah**. Jangan ambil harga dari master harga, tapi selalu tampilkan `price_per_unit` dari payload item order.

---

## 5. Enum & Konstanta Sistem

Gunakan nilai berikut untuk dropdown dan kondisi if/else di frontend:

- **Role:** `kasir`, `owner`
- **Tipe Layanan (`service_type`):** `Kiloan`, `Sepatu`, `Boneka`, `Karpet`, `Jas`
- **Status Pembayaran (`payment_status`):** `Belum Lunas`, `Lunas`
- **Status Produksi (`current_status`):** `Antrean`, `Dicuci`, `Disetrika`, `Siap Diambil`, `Selesai`
- **Status Persetujuan (`approval_status`):** `Pending`, `Approved`, `Rejected`

---

## 6. Spesifikasi Endpoint

### 6.1 Auth & User Management

**`POST /api/auth/login`**
- *Akses:* Publik
- *Body:* `{ "username": "string", "password": "string" }`
- *Response 200:* `{ "access_token": "string", "token_type": "bearer", "role": "string", "user_id": "integer" }`

**`POST /api/auth/register`**
- *Akses:* Owner saja
- *Body:* `{ "username": "string", "password": "string", "role": "kasir" | "owner" }`
- *Response 201:* Objek User baru.
- *Error 409:* Username sudah ada (Gunakan ini untuk logika "sudah ada, lanjut" di frontend jika diperlukan).

**`GET /api/auth/me`**
- *Akses:* Login
- *Response 200:* Objek User yang sedang login.

---

### 6.2 Orders (Kasir & Owner)

**`POST /api/orders`** *(FR-KSR-01, FR-KSR-02, FR-KSR-03)*
- *Akses:* Kasir, Owner
- *Fungsi:* Membuat pesanan baru, auto-create pelanggan jika nomor HP baru, langsung mengunci pesanan.
- *Body:*
  ```json
  {
    "customer_name": "string",
    "customer_phone": "string",
    "items": [
      {
        "service_type": "Kiloan",
        "weight_quantity": 3.5,
        "price_per_unit": 7000
      }
    ],
    "discount": 0,
    "tax_rate": 0.0
  }
  ```
- *Response 201:* Mengembalikan objek Order lengkap dengan `items`, `tracking_code`, dan `is_locked: true`. Nilai `subtotal`, `tax`, dan `grand_total` dihitung oleh backend.

**`GET /api/orders`**
- *Akses:* Kasir, Owner
- *Query Params:* `payment_status`, `current_status`, `customer_id`, `date_from` (YYYY-MM-DD), `date_to` (YYYY-MM-DD), `include_cancelled` (boolean, default false), `page`, `page_size`.
- *Response 200:* List Order terpaginasi. *Catatan: Secara default tidak menyertakan item detail untuk performa.*

**`GET /api/orders/{order_id}`**
- *Akses:* Kasir, Owner
- *Response 200:* Detail lengkap order termasuk array `items`.

**`PATCH /api/orders/{order_id}/status`**
- *Akses:* Kasir, Owner
- *Fungsi:* Mengubah status produksi. Akan ditolak (422) jika status mundur atau order sudah dibatalkan.
- *Body:* `{ "current_status": "Dicuci" }`

---

### 6.3 Customers (Kasir & Owner)

**`GET /api/customers`**
- *Akses:* Kasir, Owner
- *Query Params:* `search` (mencari berdasarkan nama atau nomor telepon), `page`, `page_size`.
- *Response 200:* List pelanggan terpaginasi.

**`GET /api/customers/{customer_id}`**
- *Akses:* Kasir, Owner
- *Response 200:* Detail pelanggan.

---

### 6.4 Tracking Publik (Tanpa Auth)

**`GET /api/track/{tracking_code}`** *(FR-PLG-01, FR-PLG-02, FR-PLG-03)*
- *Akses:* Publik (Tidak perlu header Authorization).
- *URL Parameter:* `tracking_code` (Format: `LND-DDMM-NNN`, contoh: `LND-3006-001`).
- *Response 200:*
  ```json
  {
    "tracking_code": "LND-3006-001",
    "customer_name": "Budi",
    "current_status": "Dicuci",
    "status_progress": 25,
    "is_cancelled": false,
    "queue_position": 3,
    "queue_ahead": 2,
    "items": [...],
    "subtotal": 10000,
    "discount": 0,
    "tax": 0,
    "grand_total": 10000,
    "order_date": "2026-06-30T10:00:00"
  }
  ```
- *Penanganan UI:*
  - Jika `is_cancelled` true, tampilkan pesan "Pesanan Dibatalkan" dan hentikan progress bar.
  - Jika `current_status` bukan "Antrean", sembunyikan komponen `queue_position` dan `queue_ahead`.
  - Gunakan `status_progress` (0-100) untuk mengatur lebar CSS progress bar linear.

---

### 6.5 Edit Requests & Governance (Kasir & Owner)

**`POST /api/edit-requests`** *(FR-KSR-04)*
- *Akses:* Kasir, Owner
- *Fungsi:* Mengajukan perbaikan data item (berat, harga, tipe) pada order yang terkunci.
- *Body:*
  ```json
  {
    "order_id": 1,
    "reason": "Salah timbang, seharusnya 4kg",
    "items": [
      {
        "order_item_id": 5,
        "service_type": "Kiloan",
        "new_weight_quantity": 4.0,
        "new_price_per_unit": 7000
      }
    ]
  }
  ```

**`POST /api/edit-requests/cancel`**
- *Akses:* Kasir, Owner
- *Fungsi:* Mengajukan pembatalan order.
- *Body:*
  ```json
  {
    "order_id": 1,
    "reason": "Pelanggan meminta pembatalan"
  }
  ```

**`GET /api/edit-requests`**
- *Akses:* Kasir, Owner
- *Query Params:* `approval_status`, `order_id`, `is_cancellation` (boolean), `page`, `page_size`.

**`GET /api/edit-requests/{request_id}`** *(FR-OWN-01)*
- *Akses:* Kasir, Owner
- *Fungsi:* Mengambil detail permintaan beserta log komparasi (Git-Diff View).
- *Response 200:* Berisi array `items` dengan properti `old_*` dan `new_*`. Gunakan ini di UI Owner untuk menampilkan tabel perbandingan (warna merah untuk nilai lama, hijau untuk nilai baru).

**`POST /api/edit-requests/{request_id}/approve`** *(FR-OWN-02)*
- *Akses:* Owner saja
- *Fungsi:* Eksekusi atomic approval. Backend akan membuka kunci, menerapkan perubahan, menghitung ulang finansial, dan mengunci kembali secara otomatis.

**`POST /api/edit-requests/{request_id}/reject`**
- *Akses:* Owner saja
- *Fungsi:* Menolak permintaan perbaikan/pembatalan.

---

### 6.6 Analytics & Laporan (Owner)

**`GET /api/analytics/financial`** *(FR-OWN-03)*
- *Akses:* Owner saja
- *Query Params:* `date_from` (YYYY-MM-DD, wajib), `date_to` (YYYY-MM-DD, wajib), `group_by` (`day` | `week` | `month`, default: `day`).
- *Response 200:* Mengembalikan `summaries` (array per periode) dan `overall` (akumulasi total). *Catatan: Data order yang `is_cancelled=true` sudah dikecualikan oleh backend.*

**`GET /api/analytics/service-breakdown`**
- *Akses:* Owner saja
- *Query Params:* `date_from` (wajib), `date_to` (wajib).
- *Response 200:* Mengelompokkan pendapatan berdasarkan `service_type`.

---

## 7. Panduan Implementasi UI Spesifik

### Form Tambah Pesanan Baru (Kasir)
1. Input Nama & No HP.
2. Gunakan komponen dynamic form untuk menambahkan array `items`. Setiap item wajib isi `service_type`, `weight_quantity`, dan `price_per_unit`.
3. Frontend bisa menampilkan preview kalkulasi `subtotal`, `tax`, dan `grand_total` secara real-time di sisi klien menggunakan JavaScript, namun **jangan** mengirim nilai hasil hitungan klien ke backend. Kirim hanya `tax_rate` dan `discount`, biarkan backend yang menghitung final nilai.
4. Setelah sukses `201`, ambil `tracking_code` dari respons untuk ditampilkan ke pelanggan (cetak struk atau kirim WA).

### Detail Pesanan (Kasir)
1. Fetch data dari `GET /api/orders/{id}`.
2. Cek properti `is_locked`.
   - Jika `true`: Tombol "Edit Pesanan" diubah menjadi "Ajukan Perbaikan".
   - Jika `true`: Input status boleh diakses (karena bukan data finansial).
3. Cek properti `is_cancelled`. Jika true, sembunyikan semua tombol aksi.

### Monitoring Antrean (Kasir/Display)
1. Fetch data `GET /api/orders?current_status=Antrean`.
2. Urutkan array berdasarkan `queue_number` di sisi klien.
3. Nomor antrean yang ditampilkan ke pelanggan diambil dari properti `queue_number`.

### Dashboard Audit (Owner)
1. Fetch `GET /api/edit-requests?approval_status=Pending`.
2. Untuk setiap item, render dua kolom: "Data Sekarang" (`old_*`) dan "Usulan" (`new_*`).
3. Jika `is_cancellation_request` true, tampilkan label khusus "Permintaan Pembatalan" dan sembunyikan tabel diff item (karena tidak ada).
4. Sediakan tombol "Terima" yang memanggil `POST /.../approve` dan "Tolak" untuk `POST /.../reject`.
