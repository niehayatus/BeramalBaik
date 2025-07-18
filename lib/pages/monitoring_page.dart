import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class MonitoringPage extends StatefulWidget {
  const MonitoringPage({super.key});

  @override
  State<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage> {
  final DatabaseReference _statusRef =
      FirebaseDatabase.instance.ref('status_daftar');
  final DatabaseReference _fingerprintRef =
      FirebaseDatabase.instance.ref('fingerprint/1');

  String namaPengelola = '-';
  bool aktifasi = false;
  List<Map<String, dynamic>> daftarPengelola = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _listenDaftarPengelola();
  }

  Future<void> _loadData() async {
    final snapshot = await _fingerprintRef.get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      setState(() {
        if (namaPengelola == '-') {
          namaPengelola = data['nama'] ?? '-';
        }
        aktifasi = data['aktifasi'] ?? false;
      });
    }
  }

  void _listenDaftarPengelola() {
    FirebaseDatabase.instance.ref('fingerprint').onValue.listen((event) {
      final dataSnapshot = event.snapshot;
      if (dataSnapshot.exists) {
        List<Map<String, dynamic>> loaded = [];
        for (var child in dataSnapshot.children) {
          final data = Map<String, dynamic>.from(child.value as Map);
          loaded.add({
            'id': child.key,
            'nama': data['nama'] ?? '-',
            'aktifasi': data['aktifasi'] ?? false,
          });
        }
        setState(() {
          daftarPengelola = loaded;
        });
      } else {
        setState(() {
          daftarPengelola = [];
        });
      }
    });
  }

  Future<void> _toggleAktifasi(bool value) async {
    await _fingerprintRef.update({'aktifasi': value});
    setState(() {
      aktifasi = value;
    });
  }

  Future<void> _aktifkanStatusDaftar() async {
    await _statusRef.set(true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('MODE DAFTAR diaktifkan')),
    );
  }

  Future<void> _editNamaDialog() async {
    String newNama = namaPengelola;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Nama Pengelola'),
          content: TextField(
            decoration: const InputDecoration(labelText: 'Nama Baru'),
            controller: TextEditingController(text: newNama),
            onChanged: (value) => newNama = value,
          ),
          actions: [
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text('Simpan'),
              onPressed: () async {
                await _fingerprintRef.update({'nama': newNama});
                setState(() {
                  namaPengelola = newNama;
                });
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _tambahPengelolaDialog() async {
    String newNama = '';

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Tambah Pengelola Baru'),
          content: TextField(
            decoration: const InputDecoration(labelText: 'Nama Pengelola'),
            onChanged: (value) => newNama = value,
          ),
          actions: [
            TextButton(
              child: const Text('Batal'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text('Tambah'),
              onPressed: () async {
                if (newNama.trim().isEmpty) return;

                final snapshot =
                    await FirebaseDatabase.instance.ref('fingerprint').get();
                final nextId = (snapshot.children.length + 1).toString();

                await FirebaseDatabase.instance
                    .ref('fingerprint/$nextId')
                    .set({'nama': newNama, 'aktifasi': false});

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pengelola baru ditambahkan')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildBox(String title, Widget content,
      {bool centerContent = false}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.green.shade600, width: 1.5),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(2, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment:
            centerContent ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(title,
              textAlign: centerContent ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800)),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildLogItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade300),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.person, size: 20, color: Colors.green),
              const SizedBox(width: 6),
              Text('${item['id']}. ${item['nama']}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: item['aktifasi'] ? Colors.green.shade100 : Colors.red.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              item['aktifasi'] ? 'AKTIF' : 'TIDAK AKTIF',
              style: TextStyle(
                color: item['aktifasi'] ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isButtonEnabled = !aktifasi;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('MONITORING'),
        centerTitle: true,
        backgroundColor: Colors.green.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildBox(
              'Informasi Pengelola',
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        namaPengelola,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: _editNamaDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Aktifasi:', style: TextStyle(fontSize: 16)),
                      Switch(
                        value: aktifasi,
                        onChanged: _toggleAktifasi,
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                ],
              ),
              centerContent: true,
            ),
            _buildBox(
              'Kontrol',
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: isButtonEnabled ? _aktifkanStatusDaftar : null,
                    icon: const Icon(Icons.lock_open),
                    label: const Text('MODE DAFTAR'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isButtonEnabled ? Colors.green : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _tambahPengelolaDialog,
                    icon: const Icon(Icons.person_add),
                    label: const Text('TAMBAH PENGELOLA'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              centerContent: true,
            ),
            _buildBox(
              'Log Pengelola Terdaftar',
              daftarPengelola.isEmpty
                  ? const Text('Belum ada pengelola yang terdaftar.')
                  : Column(
                      children: daftarPengelola
                          .map((item) => _buildLogItem(item))
                          .toList(),
                    ),
              centerContent: false,
            ),
          ],
        ),
      ),
    );
  }
}
