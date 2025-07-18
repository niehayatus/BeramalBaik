import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';


class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final dateFormatter = DateFormat('dd MMMM yyyy');
  final timeFormatter = DateFormat('yyyy-MM-dd HH:mm');

  int selectedMonth = DateTime.now().month;
  int totalPerBulan = 0;
  List<Map<String, dynamic>> transaksiList = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('history_kotak_amal')
          .orderBy('timestamp', descending: true)
          .get();

      List<Map<String, dynamic>> result = [];
      int total = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final nominal = data['nominal_uang'];
        final timestampRaw = data['timestamp'];

        if (nominal != null && timestampRaw is Timestamp) {
          final timestamp = timestampRaw.toDate();
          if (timestamp.month == selectedMonth) {
            final nominalInt = (nominal as num).toInt();
            total += nominalInt;
            result.add({
              'timestamp': timestamp,
              'nominal': nominalInt,
            });
          }
        }
      }

      setState(() {
        transaksiList = result;
        totalPerBulan = total;
      });
    } catch (e) {
      debugPrint('Firestore error: $e');
    }
  }

  Future<void> _exportToPDF() async {
  if (transaksiList.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tidak ada data untuk diekspor.')),
    );
    return;
  }

  final pdf = pw.Document();

  try {
    final ttf = pw.Font.ttf(await rootBundle.load('assets/fonts/RobotoRegular-3m4L.ttf'));
    final ttfBold = pw.Font.ttf(await rootBundle.load('assets/fonts/RobotoBold-Xdoj.ttf'));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text('Laporan Keuangan',
              style: pw.TextStyle(fontSize: 24, font: ttfBold)),
          pw.SizedBox(height: 10),
          pw.Text('Bulan: ${DateFormat.MMMM().format(DateTime(0, selectedMonth))} 2025',
              style: pw.TextStyle(font: ttf)),
          pw.Text('Total: ${currencyFormatter.format(totalPerBulan)}',
              style: pw.TextStyle(font: ttf)),
          pw.SizedBox(height: 20),
          pw.Text('Detail Transaksi:', style: pw.TextStyle(font: ttfBold, fontSize: 16)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: ['Tanggal & Waktu', 'Nominal'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, font: ttfBold),
            cellStyle: pw.TextStyle(font: ttf),
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
            border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
            cellAlignment: pw.Alignment.centerLeft,
            data: transaksiList.map<List<String>>((item) {
              final ts = item['timestamp'];
              final date = ts is Timestamp ? ts.toDate() : ts;
              final formattedDate = timeFormatter.format(date);
              final nominal = currencyFormatter.format(item['nominal']);
              return [formattedDate, nominal];
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  } catch (e) {
    debugPrint('PDF export error: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gagal membuat PDF.')),
    );
  }
}

  Future<void> _resetData() async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Reset Data'),
      content: const Text('Yakin ingin menghapus semua data di aplikasi?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ya, Hapus')),
      ],
    ),
  );

  if (confirm != true) return;

  try {
    // Hapus semua dokumen Firestore
    final snapshot = await FirebaseFirestore.instance.collection('history_kotak_amal').get();
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();

    // Reset data di Realtime Database
    final db = FirebaseDatabase.instance.ref();
    await db.child('/kotak_amal/total_uang').set(0);
    // tambahkan path lain sesuai yang kamu gunakan

    // (opsional) Hapus data lokal
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    await _loadData();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Seluruh data berhasil direset.')),
    );
  } catch (e) {
    debugPrint('Reset error: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gagal mereset data.')),
    );
  }
}

  Widget _buildBox(String title, Widget content) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.green.shade600, width: 1.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildTransaksiCard(Map<String, dynamic> item) {
    final date = item['timestamp'] as DateTime;
    final nominal = currencyFormatter.format(item['nominal']);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(dateFormatter.format(date), style: const TextStyle(fontSize: 14)),
          Text(nominal, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tampilTerbatas = transaksiList.take(5).toList(); // maksimal 5 transaksi terbaru

    return Scaffold(
      appBar: AppBar(
        title: const Text('REPORT'),
        backgroundColor: Colors.green[700],
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBox(
                'Total Bulan Ini',
                Text(currencyFormatter.format(totalPerBulan),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              _buildBox(
                'Pilih Bulan',
                DropdownButton<int>(
                  value: selectedMonth,
                  isExpanded: true,
                  items: List.generate(12, (i) {
                    return DropdownMenuItem(
                      value: i + 1,
                      child: Text(DateFormat.MMMM().format(DateTime(0, i + 1))),
                    );
                  }),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        selectedMonth = val;
                      });
                      _loadData();
                    }
                  },
                ),
              ),
              _buildBox(
                'Transaksi Harian (5 Terbaru)',
                tampilTerbatas.isEmpty
                    ? const Text('Tidak ada data untuk bulan ini.')
                    : Column(children: tampilTerbatas.map(_buildTransaksiCard).toList()),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _exportToPDF,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Export PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _resetData,
                    icon: const Icon(Icons.delete),
                    label: const Text('Reset Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
