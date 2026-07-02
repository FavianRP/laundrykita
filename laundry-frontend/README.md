# LaundryKita — Frontend (Nuxt 3)

Frontend untuk Smart Laundry POS & Automated Governance System, dibangun sesuai `README-Laundry.md` (FastAPI backend).

## Menjalankan

1. `cp .env.example .env` lalu sesuaikan `NUXT_PUBLIC_API_BASE` jika backend tidak berjalan di `http://localhost:8000/api`.
2. `npm install`
3. `npm run dev` → buka `http://localhost:3000`

## Struktur

- `app/pages/login.vue` — login kasir/owner (JWT, disimpan di localStorage)
- `app/pages/track/` — pelacakan publik tanpa login (`/track`, `/track/[code]`)
- `app/pages/orders/` — daftar, buat baru, dan detail pesanan (status produksi, ajukan perbaikan/pembatalan)
- `app/pages/customers/` — daftar dan riwayat pesanan pelanggan
- `app/pages/edit-requests/` — daftar pengajuan + tampilan git-diff & aksi terima/tolak (owner)
- `app/pages/analytics/` — laporan keuangan & breakdown layanan (owner)
- `app/stores/auth.ts` — sesi pengguna (Pinia)
- `app/composables/useApi.ts` — wrapper fetch + header Authorization + redirect saat 401
- `app/types/index.ts` — tipe data sesuai skema backend

## Aturan bisnis yang diterapkan di UI

- Order langsung terkunci setelah dibuat — tidak ada form edit langsung, hanya "Ajukan Perbaikan" / "Ajukan Pembatalan".
- Status produksi hanya bisa maju (tombol berikutnya saja yang tersedia).
- Badge "Menunggu Persetujuan Owner" saat ada pengajuan pending pada order.
- Order dibatalkan disembunyikan dari daftar default, ditampilkan dengan label saat filter `include_cancelled` aktif.
- Tracking publik menyembunyikan info antrean jika status bukan "Antrean", dan menampilkan progress bar dari `status_progress`.
- Harga item order ditampilkan dari `price_per_unit` tersimpan, bukan dari master harga.
- Halaman `/analytics` hanya dapat diakses role `owner`.
