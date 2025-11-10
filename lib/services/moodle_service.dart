import 'dart:async';
import 'dart:convert';
import 'package:esago/models/moodle_user_model.dart';
import 'package:esago/services/service_status_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MoodleService {
  final ServiceStatusService serviceStatusService;

  static const String _moodleUrl = "https://elearning.esaunggul.ac.id";
  static const String _serviceName = "moodle_mobile_app";
  static const String _tokenKey = "moodle_token";

  String? _token;
  int? _userId;
  String? _userPictureUrl;
  Map<String, int> _courses = {};

  MoodleService({required this.serviceStatusService});

  String? get token => _token;
  int? get userId => _userId;
  String? get userPictureUrl => _userPictureUrl;
  Map<String, int> get courses => _courses;
  bool get hasValidToken => _token != null;
  bool get isElearningOnline => serviceStatusService.isElearningOnline;

  Future<void> init() async {
    if (!isElearningOnline) {
      debugPrint('E-learning is offline, skipping Moodle init.');
      await clearToken();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString(_tokenKey);

    if (storedToken != null) {
      try {
        final siteInfo = await _fetchSiteInfo(storedToken);
        _token = storedToken;
        _userId = siteInfo['userid'];
        _userPictureUrl = _buildPluginFileUrl(siteInfo['userpictureurl'], _token!);
        _courses = await getMyCourses(_token!, _userId!);
      } catch (e) {
        await clearToken();
      }
    }
  }

  Future<void> login(String username, String password) async {
    if (!isElearningOnline) {
      throw Exception('Layanan E-Learning sedang tidak tersedia.');
    }

    final newToken = await _getToken(username, password);
    final siteInfo = await _fetchSiteInfo(newToken);

    _token = newToken;
    _userId = siteInfo['userid'];
    _userPictureUrl = _buildPluginFileUrl(siteInfo['userpictureurl'], _token!);
    _courses = await getMyCourses(_token!, _userId!);
    await _saveToken(_token!);
  }

  String? _buildPluginFileUrl(String? originalUrl, String token) {
    if (originalUrl == null || !originalUrl.contains('/pluginfile.php/')) return originalUrl;
    final uri = Uri.parse(originalUrl);
    final newUrl = '$_moodleUrl/webservice/pluginfile.php${uri.path.substring(uri.path.indexOf('/pluginfile.php') + 15)}?token=$token';
    return newUrl;
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    _token = null;
    _userId = null;
    _userPictureUrl = null;
    _courses = {};
  }

  Future<String> _getToken(String username, String password) async {
    const endpoint = '$_moodleUrl/login/token.php';
    final params = {'username': username, 'password': password, 'service': _serviceName};
    final uri = Uri.parse(endpoint).replace(queryParameters: params);

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      try {
        final data = json.decode(response.body);
        if (data['token'] != null) return data['token'];
        if (data['error'] != null) throw Exception('Login Moodle Gagal: ${data['error']}');
        throw Exception('Respons login Moodle tidak valid.');
      } on FormatException {
        throw Exception('Server E-Learning memberikan respons tidak terduga.');
      }
    } on TimeoutException {
      throw Exception('Koneksi ke server Moodle habis waktu.');
    }
  }

  Future<Map<String, dynamic>> _fetchSiteInfo(String token) async {
    const endpoint = '$_moodleUrl/webservice/rest/server.php';
    final params = {
      'wstoken': token,
      'wsfunction': 'core_webservice_get_site_info',
      'moodlewsrestformat': 'json',
    };
    final uri = Uri.parse(endpoint).replace(queryParameters: params);

    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    final data = json.decode(response.body);
    if (data['userid'] != null) {
      return {'userid': data['userid'], 'userpictureurl': data['userpictureurl']};
    }
    if (data['exception'] != null) throw Exception('Kesalahan API Moodle: ${data['message']}');
    throw Exception('Gagal mendapatkan Info Situs Moodle.');
  }

  Future<Map<String, int>> getMyCourses(String token, int userId) async {
    const endpoint = '$_moodleUrl/webservice/rest/server.php';
    final params = {
      'wstoken': token,
      'wsfunction': 'core_enrol_get_users_courses',
      'moodlewsrestformat': 'json',
      'userid': userId.toString(),
    };
    final uri = Uri.parse(endpoint).replace(queryParameters: params);

    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    final data = json.decode(response.body);

    if (data is List) {
      final Map<String, int> courseMap = {};
      for (var course in data) {
        if (course['shortname'] != null && course['id'] != null) {
          courseMap[course['shortname']] = course['id'];
        }
      }
      return courseMap;
    }
    if (data['exception'] != null) throw Exception('Kesalahan API Moodle: ${data['message']}');
    return {};
  }

  Future<List<MoodleUser>> getEnrolledUsers(int courseId) async {
    if (_token == null) throw Exception('Moodle token not available.');

    const endpoint = '$_moodleUrl/webservice/rest/server.php';
    final params = {
      'wstoken': _token!,
      'wsfunction': 'core_enrol_get_enrolled_users',
      'moodlewsrestformat': 'json',
      'courseid': courseId.toString(),
    };
    final uri = Uri.parse(endpoint).replace(queryParameters: params);

    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    final data = json.decode(response.body);

    if (data is List) {
      return data.map((userJson) {
        final user = MoodleUser.fromJson(userJson);
        final newImageUrl = _buildPluginFileUrl(user.profileImageUrl, _token!);
        // FIX: Provide a default empty string if newImageUrl is null
        return MoodleUser(
            id: user.id, fullname: user.fullname, profileImageUrl: newImageUrl ?? '', roles: user.roles);
      }).toList();
    }
    if (data['exception'] != null) throw Exception('Kesalahan API Moodle: ${data['message']}');
    return [];
  }
}
