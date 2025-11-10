import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacyDialog extends StatefulWidget {
  const PrivacyDialog({super.key});

  @override
  State<PrivacyDialog> createState() => _PrivacyDialogState();
}

class _PrivacyDialogState extends State<PrivacyDialog> {
  bool _isChecked = false;

  void _onAgree() async {
    if (_isChecked) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('privacy_policy_accepted', true);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF183A5D),
      title: const Text('Kebijakan Privasi & Persetujuan', style: TextStyle(color: Colors.white)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionContent(
                'Dengan menggunakan EsaGo, Anda setuju bahwa aplikasi akan mengumpulkan dan menggunakan kredensial (NIM & password) Anda untuk mengakses portal Siakad Universitas Esa Unggul atas nama Anda.\n\n'
                'Kredensial Anda hanya disimpan secara lokal di perangkat ini dan dikirim langsung ke server resmi universitas melalui koneksi aman (HTTPS). Kami tidak pernah menyimpan data Anda di server kami.'
              ),
              const SizedBox(height: 16),
              _buildSectionContent(
                'Aplikasi ini berfungsi dengan membaca data dari situs web Siakad (web scraping) untuk menampilkannya kembali dalam format yang mudah digunakan. Ini adalah aplikasi tidak resmi (unofficial).'
              ),
            ],
          ),
        ),
      ),
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Checkbox(
                  value: _isChecked,
                  onChanged: (bool? value) {
                    setState(() {
                      _isChecked = value ?? false;
                    });
                  },
                  checkColor: Colors.white,
                  activeColor: Colors.orange,
                ),
                const Expanded(
                  child: Text(
                    'Saya telah membaca, memahami, dan menyetujui kebijakan ini.',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isChecked ? _onAgree : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                disabledBackgroundColor: Colors.grey.shade700,
              ),
              child: const Text('Setuju & Lanjutkan', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ],
    );
  }

  static Widget _buildSectionContent(String content) {
    return Text(
      content,
      style: const TextStyle(fontSize: 15, color: Colors.white70, height: 1.5),
    );
  }
}
