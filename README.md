# Potential P&L Indicator for MT5

Indikator MT5 yang menampilkan potensi profit dan loss secara real-time di samping harga pada chart, dilengkapi dengan position duration display.

<img width="1717" height="767" alt="XAGUSD mM1" src="https://github.com/user-attachments/assets/9bc45e45-e877-4cbf-980b-67080c5cb79d" />

## Fitur

- **Visualisasi P&L Real-time**: Menampilkan label profit/loss di berbagai level harga
- **Position Duration**: Tampilan real-time durasi posisi dalam format yang mudah dibaca (hari, jam, menit, detik)
- **Kustomisasi Warna**: Atur warna untuk profit (hijau), loss (merah), breakeven (abu-abu), dan durasi
- **Multiple Font**: Pilih dari 10+ jenis font (Arial, Consolas, Courier New, dll)
- **Interval Fleksibel**: Sesuaikan step interval dalam dollar ($)
- **Auto-update**: Label durasi update setiap detik secara real-time
- **Hypothetical Line**: Tambahkan garis entry dan exit untuk menghitung potensi profit/loss. Jadi kamu bisa bersyukur kalau trade terakhir memang mencapai level Stop Loss, atau menyesal karena harga malah menyentuh Take Profit setelah sempat menyentuh level Breakeven. :)

## Hypothetical Line

<img width="1609" height="784" alt="XAUUSDM5_2" src="https://github.com/user-attachments/assets/68821832-e650-462d-88ae-da67e5f1c94e" />


## Cara menggunakan Hypothetical Line:
1. Buat dua Horizontal Line
2. Rename Horizontal Line menjadi "HypoEntry_1" atau "HypoExit_1"


## Instalasi

1. Copy file `PotentialRiskReward.mq5` ke folder `MQL5/Indicators/`
2. Compile di MetaEditor (F7)
3. Drag & drop ke chart dari Navigator window

## Parameter Input

| Parameter | Default | Deskripsi |
|-----------|---------|-----------|
| `clrProfit` | Lime Green | Warna teks profit |
| `clrLoss` | Deep Pink | Warna teks loss |
| `clrBreakeven` | Gray | Warna teks breakeven (entry price) |
| `fontType` | Consolas | Jenis font yang digunakan |
| `fontSize` | 9 | Ukuran font |
| `stepMoney` | 50.0 | Interval step dalam dollar ($) |
| `maxLabels` | 20 | Maksimal jumlah label per arah |
| `showPlusSign` | true | Tampilkan tanda + untuk profit |
| `showDollarSign` | true | Tampilkan simbol $ |
| `xDistance` | 5 | Jarak label dari kanan layar (pixel) |
| `showDuration` | true | Tampilkan durasi posisi |
| `clrDuration` | White | Warna teks durasi |
| `durationYOffset` | 15 | Jarak vertikal durasi dari label PnL (pixel) |

## Cara Kerja

1. Indikator mendeteksi posisi terbuka pada symbol chart aktif
2. Jika ada multiple positions, indikator menampilkan label untuk posisi yang dibuka paling awal (oldest position)
3. Menghitung harga untuk setiap interval profit/loss berdasarkan `stepMoney`
4. Menampilkan label P/L di sisi kanan chart pada level harga yang sesuai
5. Menampilkan durasi posisi yang update setiap detik (jika `showDuration` aktif)
6. Label otomatis hilang saat posisi ditutup

## Catatan

- Hanya menampilkan label untuk posisi pada symbol chart aktif
- Jika ada multiple positions pada symbol yang sama, indikator akan menampilkan label untuk posisi pertama yang dibuka (oldest position)
- Perhitungan P&L menggunakan tick size dan tick value symbol
- Label otomatis reposition saat chart di-scroll atau di-zoom
- Durasi ditampilkan dalam format:
  - `Xd Xh Xm` untuk durasi lebih dari 1 hari
  - `Xh Xm Xs` untuk durasi kurang dari 1 hari
  - `Xm Xs` untuk durasi kurang dari 1 jam
  - `Xs` untuk durasi kurang dari 1 menit