import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardPublic extends StatefulWidget {
  const DashboardPublic({super.key});

  @override
  State<DashboardPublic> createState() => _DashboardPublicState();
}

class _DashboardPublicState extends State<DashboardPublic> {
  double totalKeseluruhan = 0;
  Map<String, double> grafikMingguan = {};
  List<Map<String, dynamic>> recentList = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _loadTotal();
    await _loadGrafikMingguan();
    await _loadRecentTransaksi();
  }

  void _loadTotal() {
    final dbRef = FirebaseDatabase.instance.ref().child("kotak_amal/total_uang");
    dbRef.onValue.listen((event) {
      final val = event.snapshot.value;
      setState(() {
        totalKeseluruhan = double.tryParse(val?.toString() ?? '0') ?? 0;
      });
    });
  }

  Future<void> _loadGrafikMingguan() async {
    final now = DateTime.now();
    final DateTime startDate = now.subtract(const Duration(days: 6));

    final snapshot = await FirebaseFirestore.instance
        .collection('history_kotak_amal')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(
            DateTime(startDate.year, startDate.month, startDate.day)))
        .get();

    Map<String, double> tempData = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final timestamp = (data['timestamp'] as Timestamp).toDate();

      double nominal = 0;
      final rawNominal = data['nominal_uang'];
      if (rawNominal is int || rawNominal is double) {
        nominal = rawNominal.toDouble();
      } else if (rawNominal is String) {
        nominal = double.tryParse(rawNominal) ?? 0;
      }
      if (nominal < 0) nominal = 0;

      final dateStr = DateFormat('yyyy-MM-dd').format(timestamp);
      tempData[dateStr] = (tempData[dateStr] ?? 0) + nominal;
    }

    final result = <String, double>{};
    for (int i = 0; i < 7; i++) {
      final dateStr = DateFormat('yyyy-MM-dd')
          .format(now.subtract(Duration(days: 6 - i)));
      result[dateStr] = tempData[dateStr] ?? 0;
    }

    setState(() {
      grafikMingguan = result;
    });
  }

  Future<void> _loadRecentTransaksi() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('history_kotak_amal')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .get();

    List<Map<String, dynamic>> temp = [];
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final timestamp = (data['timestamp'] as Timestamp).toDate();
      final nominal = (data['nominal_uang'] ?? 0).toDouble();
      temp.add({
        'timestamp': timestamp,
        'nominal': nominal,
      });
    }

    setState(() {
      recentList = temp;
    });
  }

  String formatRupiah(double amount) {
    final format = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    return format.format(amount);
  }

  Widget _buildTotalCard() {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFA5D6A7), Color(0xFF66BB6A)], // full green gradient
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.green.shade300.withOpacity(0.5),
          blurRadius: 15,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.volunteer_activism, size: 40, color: Color.fromARGB(255, 3, 71, 4)),
        const SizedBox(height: 12),
        const Text(
          'Total Infak Terkumpul',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color.fromARGB(255, 0, 0, 0),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Rp ${totalKeseluruhan.toStringAsFixed(0)}',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color.fromARGB(255, 40, 105, 34),
          ),
        ),
      ],
    ),
  );
}


  Widget _buildChartCard() {
    final entries = grafikMingguan.entries.toList();
    final spots = entries.asMap().entries
        .map((entry) => FlSpot(entry.key.toDouble(),
            entry.value.value >= 0 && entry.value.value.isFinite ? entry.value.value : 0))
        .toList();

    if (spots.isEmpty) return _buildEmptyChartMessage();

    final maxY = (grafikMingguan.values.reduce((a, b) => a > b ? a : b) * 1.2).ceilToDouble();
    final yInterval = maxY > 0 ? (maxY / 5).ceilToDouble() : 1; // Fix untuk menghindari 0

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Grafik Infak Mingguan',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade900,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: yInterval.toDouble(), // Aman dari nol sekarang
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.shade300,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: true, border: Border.all(color: Colors.green.shade400)),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, _) {
                          final index = value.toInt();
                          if (index >= 0 && index < grafikMingguan.length) {
                            final dateStr = grafikMingguan.keys.elementAt(index);
                            final date = DateTime.tryParse(dateStr);
                            if (date != null) {
                              final hari = DateFormat('E', 'id_ID').format(date);
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  hari,
                                  style: TextStyle(
                                    color: Colors.green.shade800,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: yInterval.toDouble(),
                        reservedSize: 42,
                        getTitlesWidget: (value, _) {
                          if (value >= 1000000) {
                            return Text('${(value / 1000000).toStringAsFixed(1)}M', style: const TextStyle(fontSize: 11));
                          } else if (value >= 1000) {
                            return Text('${(value / 1000).toStringAsFixed(0)}K', style: const TextStyle(fontSize: 11));
                          } else {
                            return Text(value.toStringAsFixed(0), style: const TextStyle(fontSize: 11));
                          }
                        },
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.green.shade700,
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(show: true, color: Colors.green.shade200.withOpacity(0.3)
                    ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChartMessage() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.bar_chart, color: Colors.green.shade400, size: 48),
            const SizedBox(height: 12),
            Text(
              'Belum ada data infak minggu ini',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.green.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentList() {
    final displayList = recentList.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Detail Infak Terakhir',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade900,
              ),
            ),
            TextButton(
              onPressed: _showAllRecentDialog,
              child: const Text('Lihat Semua'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...displayList.map((item) {
          final waktu = item['timestamp'] as DateTime;
          final nominal = item['nominal'] as double;
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.green.shade300),
            ),
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              leading: const Icon(Icons.monetization_on, color: Colors.green),
              title: Text(formatRupiah(nominal)),
              subtitle: Text(DateFormat('dd MMM yyyy, HH:mm').format(waktu)),
            ),
          );
        }),
      ],
    );
  }

  void _showAllRecentDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Semua Transaksi Terbaru'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: recentList.length,
            itemBuilder: (_, index) {
              final item = recentList[index];
              final waktu = item['timestamp'] as DateTime;
              final nominal = item['nominal'] as double;
              return ListTile(
                leading: const Icon(Icons.monetization_on, color: Colors.green),
                title: Text(formatRupiah(nominal)),
                subtitle: Text(DateFormat('dd MMM yyyy, HH:mm').format(waktu)),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('DASHBOARD PUBLIK'),
        backgroundColor: Colors.green.shade700,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildTotalCard(),
              const SizedBox(height: 24),
              _buildChartCard(),
              const SizedBox(height: 24),
              _buildRecentList(),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.center,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  icon: const Icon(Icons.login, size: 20),
                  label: const Text(
                    "Login untuk Donasi",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 6,
                    shadowColor: Colors.green.shade200,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
