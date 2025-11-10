import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum ServiceStatus { unknown, online, offline }

class ServiceStatusService with ChangeNotifier {
  final Map<String, String> _serviceUrls = {
    'siakad': 'https://siakad.esaunggul.ac.id',
    'sso': 'https://sso.esaunggul.ac.id',
    'elearning': 'https://elearning.esaunggul.ac.id',
  };

  final Map<String, ServiceStatus> _statuses = {
    'siakad': ServiceStatus.unknown,
    'sso': ServiceStatus.unknown,
    'elearning': ServiceStatus.unknown,
  };

  ServiceStatus get siakadStatus => _statuses['siakad']!;
  ServiceStatus get ssoStatus => _statuses['sso']!;
  ServiceStatus get elearningStatus => _statuses['elearning']!;
  bool get isElearningOnline => _statuses['elearning'] == ServiceStatus.online;

  // Ganti nama kembali agar sesuai dengan pemanggilan di main.dart
  Future<void> checkAllServices() async {
    debugPrint('Performing definitive deep checks on all services...');
    await Future.wait([
      _checkSsoStatus(),
      _checkSiakadStatus(),
      _checkElearningStatus(), // Menggunakan logika baru yang andal
    ]);
    debugPrint('Service status check complete: $_statuses');
    notifyListeners();
  }

  // LOGIKA BARU YANG DEFINITIF UNTUK E-LEARNING
  Future<void> _checkElearningStatus() async {
    const serviceName = 'elearning';
    try {
      // Coba akses endpoint API yang dilindungi dengan token palsu
      final uri = Uri.parse(_serviceUrls[serviceName]! + '/webservice/rest/server.php').replace(
        queryParameters: {
          'wstoken': 'faketoken', // Token palsu
          'wsfunction': 'core_webservice_get_site_info',
          'moodlewsrestformat': 'json'
        }
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 7));
      
      // Coba parse JSON. Server sehat akan mengembalikan JSON error (invalid token).
      final data = json.decode(response.body);
      
      // Jika parsing berhasil dan berisi exception (seperti yang diharapkan), layanan online.
      if (data['exception'] != null) {
        _statuses[serviceName] = ServiceStatus.online;
        debugPrint('E-learning check PASSED (service is usable, returned valid JSON error).');
      } else {
        // Jika JSON valid tapi format tidak terduga
        _statuses[serviceName] = ServiceStatus.offline;
        debugPrint('E-learning check FAILED (usable but unexpected JSON format).');
      }

    } catch (e) {
      // Jika parsing JSON gagal (FormatException) atau timeout/error jaringan,
      // berarti layanan tidak sehat.
      _statuses[serviceName] = ServiceStatus.offline;
      debugPrint('E-learning check FAILED (service is unusable or unreachable): $e');
    }
  }

  Future<void> _checkSsoStatus() async {
    const serviceName = 'sso';
    try {
      final response = await http.post(
        Uri.parse(_serviceUrls[serviceName]! + '/login/process2'),
        body: {'username': '', 'password': ''},
      ).timeout(const Duration(seconds: 7));
      if (response.statusCode == 200 && (response.body == '1' || response.body == '2')) {
        _statuses[serviceName] = ServiceStatus.online;
      } else {
        _statuses[serviceName] = ServiceStatus.offline;
      }
    } catch (e) {
      _statuses[serviceName] = ServiceStatus.offline;
    }
  }

  Future<void> _checkSiakadStatus() async {
    const serviceName = 'siakad';
    try {
      final response = await http.head(Uri.parse(_serviceUrls[serviceName]!))
          .timeout(const Duration(seconds: 7));
      if (response.statusCode >= 200 && response.statusCode < 400) {
        _statuses[serviceName] = ServiceStatus.online;
      } else {
        _statuses[serviceName] = ServiceStatus.offline;
      }
    } catch (e) {
      _statuses[serviceName] = ServiceStatus.offline;
    }
  }
}
