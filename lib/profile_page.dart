import 'dart:typed_data';
import 'package:esago/models/schedule_model.dart';
import 'package:esago/models/siakad_data.dart';
import 'package:esago/schedule_page.dart';
import 'package:esago/services/moodle_service.dart';
import 'package:esago/services/service_status_service.dart';
import 'package:esago/services/siakad_service.dart';
import 'package:esago/sso_page.dart';
import 'package:esago/widget_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  final SiakadData siakadData;
  final MoodleService moodleService;

  const ProfilePage({
    super.key,
    required this.siakadData,
    required this.moodleService,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const platform = MethodChannel('com.esadigitallabs.esago/widget');

  Uint8List? _imageData;

  @override
  void initState() {
    super.initState();
    if (widget.moodleService.isElearningOnline) {
      _fetchProfileImage();
    }
  }

  Future<void> _fetchProfileImage() async {
    if (!widget.moodleService.isElearningOnline) return;

    final pictureUrl = widget.moodleService.userPictureUrl;
    if (pictureUrl == null || pictureUrl.isEmpty) return;

    try {
      final response = await http.get(Uri.parse(pictureUrl));
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _imageData = response.bodyBytes;
        });
      }
    } catch (e) {
      debugPrint('Image fetch failed with exception: $e');
    }
  }

  Future<void> _logout(BuildContext context) async {
    await widget.moodleService.clearToken();
    final siakadService = SiakadService(widget.moodleService);
    await siakadService.clearCookies();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    await sendDataToWidget(FullScheduleData(weeklySchedules: [], dailySchedules: [], examSchedules: []));

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const SsoPage()),
      (route) => false,
    );
  }

  Future<void> _requestPinWidget() async {
    try {
      await platform.invokeMethod('requestPinWidget');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permintaan untuk menambahkan widget telah dikirim. Silakan periksa layar utama Anda.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to pin widget: '${e.message}'.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menambahkan widget: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } 
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.siakadData.profile;

    return Consumer<ServiceStatusService>(
      builder: (context, statusService, child) {
        final bool isElearningOnline = statusService.isElearningOnline;

        return Scaffold(
          backgroundColor: const Color(0xFF0A1931),
          appBar: AppBar(
            title: const Text('Profil Mahasiswa'),
            backgroundColor: const Color(0xFF0A1931),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.add_to_home_screen),
                tooltip: 'Tambah Widget',
                onPressed: _requestPinWidget,
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
                onPressed: () => _logout(context),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 24.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - 150),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Card(
                    color: const Color(0xFF183A5D),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              if (isElearningOnline)
                                CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.orange,
                                  child: (_imageData != null)
                                      ? ClipOval(
                                          child: Image.memory(
                                            _imageData!,
                                            fit: BoxFit.cover,
                                            width: 80,
                                            height: 80,
                                          ),
                                        )
                                      : const Icon(Icons.person, size: 40, color: Colors.white),
                                ),
                              if (isElearningOnline)
                                const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: isElearningOnline
                                      ? CrossAxisAlignment.start
                                      : CrossAxisAlignment.center,
                                  children: [
                                    Text(profile.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(profile.nim, style: const TextStyle(color: Colors.white70, fontSize: 16)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32, color: Colors.white24),
                          _buildProfileInfoRow('Fakultas/Jurusan', profile.faculty),
                          _buildProfileInfoRow('Semester', profile.studentSemester),
                          _buildProfileInfoRow('Periode Masuk', profile.entryPeriod),
                          _buildProfileInfoRow('Jenis Kelamin', profile.gender),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SchedulePage(
                              scheduleData: widget.siakadData.schedule,
                              moodleService: widget.moodleService, // Moodle service is passed here
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      child: const Text('LIHAT JADWAL'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(width: 24),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
