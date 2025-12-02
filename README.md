# Potential P&L Indicator for MT5

Indikator MT5 yang menampilkan potensi profit dan loss secara real-time di samping harga pada chart.

## Fitur

- **Visualisasi P&L Real-time**: Menampilkan label profit/loss di berbagai level harga
- **Kustomisasi Warna**: Atur warna untuk profit (hijau), loss (merah), dan breakeven (abu-abu)
- **Multiple Font**: Pilih dari 10+ jenis font (Arial, Consolas, Courier New, dll)
- **Interval Fleksibel**: Sesuaikan step interval dalam dollar ($)
- **Auto-update**: Label otomatis update saat chart berubah atau ada pergerakan harga

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

## Cara Kerja

1. Indikator mendeteksi posisi terbuka pada symbol chart aktif
2. Menghitung harga untuk setiap interval profit/loss berdasarkan `stepMoney`
3. Menampilkan label di sisi kanan chart pada level harga yang sesuai
4. Label otomatis hilang saat posisi ditutup

## Catatan

- Hanya menampilkan label untuk posisi pada symbol chart aktif
- Perhitungan P&L menggunakan tick size dan tick value symbol
- Label otomatis reposition saat chart di-scroll atau di-zoom