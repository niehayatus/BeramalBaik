import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AuthService _authService = AuthService();
  bool isLoading = true;

  double totalKeseluruhan = 0;
  late DatabaseReference _totalRef;
  StreamSubscription<DatabaseEvent>? _totalSub;

  Map<String, double> grafikMingguan = {};
  List<Map<String, dynamic>> recentList = [];

  @override
  void initState() {
    super.initState();
    _startTotalListener();
    fetchData();
  }

  void _startTotalListener() {
    _totalRef = FirebaseDatabase.instance.ref('kotak_amal/total_uang');
    _totalSub = _totalRef.onValue.listen((event) {
      final val = event.snapshot.value;
      setState(() {
        totalKeseluruhan = double.tryParse(val?.toString() ?? '0') ?? 0;
      });
    });
  }

  @override
  void dispose() {
    _totalSub?.cancel();
    super.dispose();
  }

  Future<void> fetchData() async {
    setState(() => isLoading = true);
    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore.collection('history_kotak_amal').get();

      DateTime now = DateTime.now();
      DateFormat formatter = DateFormat('yyyy-MM-dd');
      List<String> last7Days = List.generate(
        7,
        (i) => formatter.format(now.subtract(Duration(days: 6 - i))),
      );

      Map<String, double> tempGrafik = {for (var d in last7Days) d: 0};
      List<Map<String, dynamic>> tempRecent = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('timestamp') && data.containsKey('nominal_uang')) {
          Timestamp ts = data['timestamp'];
          DateTime dt = ts.toDate();
          String dateStr = formatter.format(dt);

          if (last7Days.contains(dateStr)) {
            tempGrafik[dateStr] = (tempGrafik[dateStr] ?? 0) + (data['nominal_uang'] as num).toDouble();
          }

          tempRecent.add({
            'nominal': data['nominal_uang'],
            'timestamp': dt,
          });
        }
      }

      tempRecent.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

      setState(() {
        grafikMingguan = {
          for (var date in last7Days) date: tempGrafik[date] ?? 0
        };
        recentList = tempRecent.take(10).toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetchData: $e');
      setState(() => isLoading = false);
    }
  }

  Widget _buildTotalCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade100, Colors.green.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade200,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.volunteer_activism, size: 36, color: Colors.green),
          const SizedBox(height: 12),
          const Text(
            'Total Infak Terkumpul',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Rp ${totalKeseluruhan.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    final entries = grafikMingguan.entries.toList();
    final spots = entries.asMap().entries.map((entry) => FlSpot(entry.key.toDouble(), entry.value.value)).toList();

    if (spots.isEmpty) return _buildEmptyChartMessage();

    final maxY = (grafikMingguan.values.reduce((a, b) => a > b ? a : b) * 1.2).ceilToDouble();
    final yInterval = (maxY / 5).ceilToDouble();

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
                    horizontalInterval: yInterval,
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
                        interval: yInterval,
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
                      belowBarData: BarAreaData(show: true, color: Colors.green.shade200.withOpacity(0.3)),
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
              onPressed: () => _showAllRecentDialog(),
              child: const Text('Lihat Semua'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...displayList.map((item) {
          final DateTime waktu = item['timestamp'];
          final double nominal = item['nominal'] is num ? (item['nominal'] as num).toDouble() : 0;
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              leading: const Icon(Icons.monetization_on, color: Colors.green),
              title: Text("Rp ${nominal.toStringAsFixed(0)}"),
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
      builder: (_) {
        return AlertDialog(
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
                  title: Text("Rp ${nominal.toStringAsFixed(0)}"),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        title: const Text('BeramalBaik', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.green[700]),
              child: const Center(child: Text('Menu', style: TextStyle(color: Colors.white, fontSize: 28))),
            ),
            ListTile(
              leading: const Icon(Icons.monitor),
              title: const Text('Monitoring'),
              onTap: () => Navigator.pushNamed(context, '/monitoring'),
            ),
            ListTile(
              leading: const Icon(Icons.insert_chart),
              title: const Text('Report'),
              onTap: () => Navigator.pushNamed(context, '/report'),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                _authService.logout(context);
              },
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTotalCard(),
                    const SizedBox(height: 16),
                    _buildChartCard(),
                    const SizedBox(height: 24),
                    _buildRecentList(),
                  ],
                ),
              ),
            ),
    );
  }
}
