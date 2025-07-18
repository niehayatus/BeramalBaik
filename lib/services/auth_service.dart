import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🔐 Register dengan username & password
  Future<String?> register(String username, String password) async {
    try {
      final email = '$username@beramalbaik.com';

      // Cek apakah username sudah dipakai
      final userDoc = await _firestore.collection('users').doc(username).get();
      if (userDoc.exists) return 'Username sudah dipakai';

      // Register user di Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Tunggu sejenak
      await Future.delayed(const Duration(seconds: 1));

      // Validasi user aktif
      if (_auth.currentUser == null) {
        return 'Terjadi kesalahan saat autentikasi. Coba lagi.';
      }

      // Simpan user ke Firestore
      await _firestore.collection('users').doc(username).set({
        'username': username,
        'uid': userCredential.user?.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null; // sukses
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Terjadi kesalahan: ${e.toString()}';
    }
  }

  // 🔓 Login dengan username & password
  Future<String?> login(String username, String password) async {
    try {
      final email = '$username@beramalbaik.com';
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // 🚪 Logout dengan dialog konfirmasi yang estetik
  Future<void> logout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.only(top: 24),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        title: Column(
          children: const [
            Icon(Icons.logout, size: 48, color: Colors.red),
            SizedBox(height: 12),
            Text(
              "Konfirmasi Logout",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: const Text(
          "Apakah kamu yakin ingin keluar dari akun?",
          style: TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await _auth.signOut();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }
}
