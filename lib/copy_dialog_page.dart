import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CopyDialogPage extends StatefulWidget {
  final String? lecturerName;

  const CopyDialogPage({super.key, this.lecturerName});

  @override
  State<CopyDialogPage> createState() => _CopyDialogPageState();
}

class _CopyDialogPageState extends State<CopyDialogPage> {
  @override
  void initState() {
    super.initState();
    // Tampilkan dialog segera setelah halaman dimuat
    WidgetsBinding.instance.addPostFrameCallback((_) => _showCopyDialog());
  }

  void _showCopyDialog() {
    final lecturer = widget.lecturerName;
    if (lecturer == null || lecturer.trim().isEmpty) {
      // Jika tidak ada nama dosen, tutup saja halamannya
      Navigator.of(context).pop();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Salin Nama Dosen'),
          content: Text('Anda ingin menyalin "$lecturer" ke clipboard?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Tidak'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop(); // Tutup halaman transparan
              },
            ),
            TextButton(
              child: const Text('Ya'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: lecturer));
                Navigator.of(dialogContext).pop();
                Navigator.of(context).pop(); // Tutup halaman transparan
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nama dosen disalin ke clipboard')),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Halaman ini hanya sebagai latar belakang transparan untuk dialog
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(), // Tidak ada konten yang terlihat
    );
  }
}
