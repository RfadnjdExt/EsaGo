import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:esago/models/profile_model.dart';
import 'package:esago/models/schedule_model.dart';
import 'package:esago/models/siakad_data.dart';
import 'package:esago/services/moodle_service.dart';
import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class SiakadService {
  static const String _baseUrl = 'https://siakad.esaunggul.ac.id';
  static const String _gateUrl = '$_baseUrl/front/gate/index.php';
  static const String _siakadUrl = '$_baseUrl/siakad/siakad/index.php';
  static const String _cookieKey = 'siakad_cookies';

  final CookieJar _cookieJar;
  final MoodleService _moodleService;

  SiakadService(this._moodleService)
      : _cookieJar = CookieJar();

  Future<void> init() async {
    await _loadCookiesFromPrefs();
  }

  Future<void> clearCookies() async {
    await _cookieJar.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cookieKey);
  }

  Future<SiakadData> loginSsoAndFetchData(String nim, String password) async {
    final client = http.Client();
    try {
      // SSO Login
      final ssoResponse = await client.post(
        Uri.parse('https://sso.esaunggul.ac.id/login/process2'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': nim, 'password': password},
      ).timeout(const Duration(seconds: 10));

      final ssoBody = ssoResponse.body;
      if (ssoBody != 'true') {
        String errorMessage;
        switch (ssoBody) {
          case '1':
            errorMessage = 'Nama Pengguna / Kata Sandi Salah';
            break;
          case '2':
            errorMessage = 'Kata Sandi Anda Salah';
            break;
          case '3':
            errorMessage = 'Akun Anda Sudah Tidak Aktif';
            break;
          case '4':
            errorMessage = 'Akun Anda dinonaktifkan karena melakukan pelanggaran';
            break;
          default:
            errorMessage = 'Terjadi kesalahan yang tidak diketahui. Coba lagi.';
        }
        throw Exception(errorMessage);
      }

      // If SSO login is successful, proceed to fetch Siakad data
      return await fetchSiakadData(nim, password);
    } finally {
      client.close();
    }
  }

  Future<SiakadData> fetchSiakadDataWithCookie() async {
    final client = http.Client();
    try {
      final initialCookies = await _cookieJar.loadForRequest(Uri.parse(_siakadUrl));
      if (initialCookies.isEmpty) {
        throw Exception('No session cookie found.');
      }

      final scheduleHtml = await _fetchRawScheduleHtml(client);
      final document = html_parser.parse(scheduleHtml);

      final loginForm = document.querySelector('form[name="frmlogin"]');
      if (loginForm != null) {
        await clearCookies();
        throw Exception('Session expired. Please login again.');
      }

      final studentProfile = _parseStudentProfile(document);
      if (studentProfile.nim.isEmpty) {
        await clearCookies();
        throw Exception('Failed to parse student profile. Session might be invalid.');
      }

      final fullSchedule = _parseFullSchedule(document);
      return SiakadData(profile: studentProfile, schedule: fullSchedule);
    } catch (e, s) {
      debugPrint('Error fetching Siakad data with cookie: $e\n$s');
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<SiakadData> fetchSiakadData(String nim, String password, {bool skipNavigation = false}) async {
    final client = http.Client();
    try {
      if (!skipNavigation) {
          await clearCookies();
          await _performLogin(client, nim, password);
          final sessionData = await _navigateToAcademicRole(client);
          await _finalizeSession(client, sessionData);
      }

      final scheduleHtml = await _fetchRawScheduleHtml(client);
      final document = html_parser.parse(scheduleHtml);

      final studentProfile = _parseStudentProfile(document);
      final fullSchedule = _parseFullSchedule(document);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nim', nim);
      await prefs.setString('password', password);

      return SiakadData(profile: studentProfile, schedule: fullSchedule);
    } catch (e, s) {
      debugPrint('Error during Siakad data fetch: $e\n$s');
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<void> _performLogin(http.Client client, String nim, String password) async {
    final loginUri = Uri.parse(_gateUrl);
    final response = await client.post(
      loginUri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'txtUserID': nim, 'txtPassword': password},
    );

    if (response.body.contains("User ID atau Password anda salah")) {
      throw Exception("User ID atau Password anda salah");
    }
    await _saveCookies(loginUri, response.headers);
  }

  Future<String> _navigateToAcademicRole(http.Client client) async {
    final menuUri = Uri.parse('$_gateUrl?page=menu');
    final menuHtml = await _fetchWithCookies(client, menuUri);
    final menuDocument = html_parser.parse(menuHtml);
    final akadRoleElement = menuDocument.querySelector('div#akad span.role_container[onclick]');
    if (akadRoleElement == null) throw Exception('Academic role element not found.');

    final onClickAttribute = akadRoleElement.attributes['onclick'];
    if (onClickAttribute == null) throw Exception('OnClick attribute not found on role.');

    final regex = RegExp(r"goAccess\('([^']*)',\s*'([^']*)',\s*'([^']*)',\s*'([^']*)',\s*'([^']*)'\)");
    final match = regex.firstMatch(onClickAttribute);
    if (match == null) throw Exception('Could not parse role information from onClick attribute.');

    final pValue = '${match.group(1)}_${match.group(2)}_${match.group(3)}_${match.group(4)}_${match.group(5)}';
    final ajaxUri = Uri.parse('$_gateUrl?page=ajax');
    final accessResponse = await client.post(
      ajaxUri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded', 'Cookie': await _getCookies(ajaxUri)},
      body: {'c': 'access', 'p': pValue},
    );
    await _saveCookies(ajaxUri, accessResponse.headers);

    final accessResponseBody = accessResponse.body;
    if (accessResponseBody.split(':').length <= 1) throw Exception("Invalid session data from role access: $accessResponseBody");

    return accessResponseBody.split(':')[1];
  }

  Future<void> _finalizeSession(http.Client client, String sessionData) async {
    final finalizeUri = Uri.parse('$_siakadUrl?page=login');
    final response = await client.post(
      finalizeUri,
      headers: {'Content-Type': 'application/x-www-form-urlencoded', 'Cookie': await _getCookies(finalizeUri)},
      body: {'sessdata': sessionData},
    );
    await _saveCookies(finalizeUri, response.headers);
  }

  Future<String> _fetchRawScheduleHtml(http.Client client) async {
    final scheduleUri = Uri.parse('$_siakadUrl?page=view_jadwalkuliah');
    return _fetchWithCookies(client, scheduleUri);
  }

  StudentProfile _parseStudentProfile(Document document) {
    final table = document.querySelector('table[width="700"][cellpadding="4"]');
    if (table == null) throw Exception('Student profile table not found');
    String name = '', nim = '', gender = '', faculty = '', entryPeriod = '', studentSemester = '';
    final rows = table.querySelectorAll('tr');

    if (rows.isNotEmpty) {
      final firstRowCells = rows[0].querySelectorAll('td');
      if (firstRowCells.length > 5) {
        name = firstRowCells[2].text.trim();
        faculty = firstRowCells[5].text.trim();
      }
    }
    if (rows.length > 1) {
      final secondRowCells = rows[1].querySelectorAll('td');
      if (secondRowCells.length > 5) {
        nim = secondRowCells[2].text.trim();
        entryPeriod = secondRowCells[5].text.trim();
      }
    }
    if (rows.length > 2) {
      final thirdRowCells = rows[2].querySelectorAll('td');
      if (thirdRowCells.length > 5) {
        gender = thirdRowCells[2].text.trim();
        studentSemester = thirdRowCells[5].text.trim();
      }
    }

    return StudentProfile(
      name: name,
      nim: nim,
      gender: gender,
      faculty: faculty,
      entryPeriod: entryPeriod,
      studentSemester: studentSemester,
    );
  }

  FullScheduleData _parseFullSchedule(Document document) {
    return FullScheduleData(
      weeklySchedules: _parseWeeklySchedules(document),
      dailySchedules: _parseDailySchedules(document),
      examSchedules: _parseExamSchedules(document),
    );
  }

  List<WeeklySchedule> _parseWeeklySchedules(Document document) {
    final moodleCourses = _moodleService.courses;
    final List<WeeklySchedule> weeklySchedules = [];

    _parseScheduleSection(
      document: document,
      sectionTitle: 'Jadwal Perkuliahan Mingguan',
      endSectionTitles: ['Jadwal Perkuliahan Harian', 'Jadwal UTS/UAS'],
      tableRowSelector: 'tr.AlternateBG, tr.NormalBG',
      onTableParse: (day, rows) {
        final entries = <ScheduleEntry>[];
        for (var row in rows) {
          final cells = row.querySelectorAll('td');
          if (cells.length < 7) continue;

          final linkElement = cells[6].querySelector('img[onClick*="goOpenpage"]');
          int? moodleCourseId;

          if (linkElement != null) {
            final idAttr = linkElement.attributes['id'] ?? '';
            final parts = idAttr.split('|');
            if (parts.length >= 5) {
              // Format: 20251CIE304BKH002
              final shortname = '${parts[3]}${parts[1]}B${parts[4]}';
              moodleCourseId = moodleCourses[shortname];
            }
          }

          entries.add(ScheduleEntry(
            startTime: cells[0].text.trim(),
            endTime: cells[1].text.trim(),
            courseCode: cells[2].text.trim(),
            courseName: cells[3].text.trim(),
            session: cells[4].text.trim(),
            room: cells[5].text.trim(),
            moodleCourseId: moodleCourseId,
          ));
        }
        if (entries.isNotEmpty) {
          weeklySchedules.add(WeeklySchedule(day: day, entries: entries));
        }
      },
    );
    return weeklySchedules;
  }

  List<DailySchedule> _parseDailySchedules(Document document) {
    final List<DailySchedule> dailySchedules = [];
    _parseScheduleSection(
      document: document,
      sectionTitle: 'Jadwal Perkuliahan Harian',
      endSectionTitles: ['Jadwal UTS/UAS'],
      tableRowSelector: 'tr.GrayBG',
      onTableParse: (day, rows) {
        final entries = <DailyEntry>[];
        for (var row in rows) {
          final cells = row.querySelectorAll('td');
          if (cells.length >= 9) {
            entries.add(DailyEntry(
              meeting: cells[0].text.trim(),
              startTime: cells[1].text.trim(),
              endTime: cells[2].text.trim(),
              courseName: cells[3].text.trim(),
              lecturer: cells[4].text.trim(),
              type: cells[5].text.trim(),
              topic: cells[6].text.trim(),
              room: cells[7].text.trim(),
              implementation: cells[8].text.trim(),
            ));
          }
        }
        if (entries.isNotEmpty) {
          dailySchedules.add(DailySchedule(day: day, entries: entries));
        }
      },
    );
    return dailySchedules;
  }

  List<ExamSchedule> _parseExamSchedules(Document document) {
    final List<ExamSchedule> examSchedules = [];
    _parseScheduleSection(
      document: document,
      sectionTitle: 'Jadwal UTS/UAS',
      endSectionTitles: [],
      tableRowSelector: 'tr.AlternateBG, tr.NormalBG',
      onTableParse: (day, rows) {
        final entries = <ExamEntry>[];
        for (var row in rows) {
          final cells = row.querySelectorAll('td');
          if (cells.length >= 8) {
            entries.add(ExamEntry(
              startTime: cells[0].text.trim(),
              endTime: cells[1].text.trim(),
              courseCode: cells[2].text.trim(),
              courseName: cells[3].text.trim(),
              session: cells[4].text.trim(),
              examType: cells[5].text.trim(),
              group: cells[6].text.trim(),
              room: cells[7].text.trim(),
            ));
          }
        }
        if (entries.isNotEmpty) {
          examSchedules.add(ExamSchedule(day: day, entries: entries));
        }
      },
    );
    return examSchedules;
  }

  void _parseScheduleSection({
    required Document document,
    required String sectionTitle,
    required List<String> endSectionTitles,
    required String tableRowSelector,
    required void Function(String day, List<Element> rows) onTableParse,
  }) {
    bool sectionStarted = false;
    for (var element in document.querySelectorAll('.ViewTitle, table.GridStyle')) {
      final elementText = element.text;
      if (element.className == 'ViewTitle' && elementText.contains(sectionTitle)) {
        sectionStarted = true;
        continue;
      }
      if (element.className == 'ViewTitle' && endSectionTitles.any(elementText.contains)) {
        sectionStarted = false;
        break;
      }

      if (sectionStarted && element.localName == 'table') {
        final header = element.querySelector('.SubHeaderBG');
        if (header == null) continue;
        final day = header.text.trim();
        final tableRows = element.querySelectorAll(tableRowSelector);
        onTableParse(day, tableRows);
      }
    }
  }

  Future<String> _fetchWithCookies(http.Client client, Uri uri) async {
    final response = await client.get(uri, headers: {'Cookie': await _getCookies(uri)});
    await _saveCookies(uri, response.headers);
    return response.body;
  }

  Future<String> _getCookies(Uri uri) async {
    final cookies = await _cookieJar.loadForRequest(uri);
    return cookies.map((c) => '${c.name}=${c.value}').join('; ');
  }

  Future<void> _saveCookies(Uri uri, Map<String, String> headers) async {
    final String? setCookieHeader = headers['set-cookie'];
    if (setCookieHeader == null) return;

    final List<Cookie> cookies = [];
    final parts = setCookieHeader.split(RegExp(r',(?=[^;]*=)'));
    for (final part in parts) {
      try {
        if (part.trim().isNotEmpty) {
          cookies.add(Cookie.fromSetCookieValue(part));
        }
      } catch (e) {
        // Ignore invalid cookie parts
      }
    }
    await _cookieJar.saveFromResponse(uri, cookies);
    await _saveCookiesToPrefs();
  }

  Future<void> _saveCookiesToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final uri = Uri.parse(_baseUrl);
    final cookies = await _cookieJar.loadForRequest(uri);
    final List<String> cookieList = cookies.map((c) {
      final Map<String, dynamic> cookieMap = {
        'name': c.name,
        'value': c.value,
        'domain': c.domain,
        'path': c.path,
        'expires': c.expires?.toIso8601String(),
        'httpOnly': c.httpOnly,
        'secure': c.secure,
        'max-age': c.maxAge,
      };
      return json.encode(cookieMap);
    }).toList();
    await prefs.setStringList(_cookieKey, cookieList);
  }

  Future<void> _loadCookiesFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final cookieList = prefs.getStringList(_cookieKey);
    if (cookieList == null) return;

    final uri = Uri.parse(_baseUrl);
    final List<Cookie> cookies = [];
    for (var cookieString in cookieList) {
      try {
        final Map<String, dynamic> cookieMap = json.decode(cookieString);
        if (cookieMap['name'] != null && cookieMap['value'] != null) {
          final cookie = Cookie(cookieMap['name'], cookieMap['value']);
          cookie.domain = cookieMap['domain'];
          cookie.path = cookieMap['path'];
          if (cookieMap['expires'] != null) {
            cookie.expires = DateTime.parse(cookieMap['expires']);
          }
          cookie.httpOnly = cookieMap['httpOnly'] ?? true;
          cookie.secure = cookieMap['secure'] ?? false;
          cookie.maxAge = cookieMap['max-age'];
          cookies.add(cookie);
        }
      } catch (e) {
        debugPrint("Error decoding cookie: $e");
      }
    }
    await _cookieJar.saveFromResponse(uri, cookies);
  }
}
