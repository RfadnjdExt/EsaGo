import 'dart:io';
import 'package:esago/copy_dialog_page.dart';
import 'package:esago/models/siakad_data.dart';
import 'package:esago/privacy_dialog.dart';
import 'package:esago/profile_page.dart';
import 'package:esago/services/moodle_service.dart';
import 'package:esago/services/service_status_service.dart';
import 'package:esago/services/siakad_service.dart';
import 'package:esago/sso_page.dart';
import 'package:esago/widget_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
void backgroundCallback(Uri? uri) async {
  if (uri?.host == 'update_widget') {
    final serviceStatusService = ServiceStatusService();
    final moodleService = MoodleService(serviceStatusService: serviceStatusService);
    final siakadService = SiakadService(moodleService);

    try {
      await moodleService.init();
      final siakadData = await siakadService.fetchSiakadDataWithCookie();
      await sendDataToWidget(siakadData.schedule);
    } catch (e) {
      debugPrint('[backgroundCallback] Failed to update widget: $e');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HomeWidget.registerBackgroundCallback(backgroundCallback);
  await initializeDateFormatting('id_ID', null);
  
  final serviceStatusService = ServiceStatusService();
  serviceStatusService.checkAllServices();

  runApp(MyApp(serviceStatusService: serviceStatusService));
}

class MyApp extends StatelessWidget {
  final ServiceStatusService serviceStatusService;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  MyApp({Key? key, required this.serviceStatusService}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: serviceStatusService,
      child: MaterialApp(
        navigatorKey: navigatorKey, 
        title: 'Esa Unggul SSO',
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: Colors.orange,
          scaffoldBackgroundColor: const Color(0xFF0A1931),
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange, brightness: Brightness.dark),
        ),
        home: const AuthCheck(),
      ),
    );
  }
}

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  late final MoodleService _moodleService;

  @override
  void initState() {
    super.initState();
    final serviceStatusService = context.read<ServiceStatusService>();
    _moodleService = MoodleService(serviceStatusService: serviceStatusService);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final isPrivacyAccepted = prefs.getBool('privacy_policy_accepted') ?? false;

      if (!isPrivacyAccepted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) => const PrivacyDialog(),
        );
      }
      
      _checkLoginStatus();
    });
  }

  Future<void> _checkLoginStatus() async {
    if (!mounted) return;

    final siakadService = SiakadService(_moodleService);

    try {
      await _moodleService.init(); // Cek e-learning dulu
      final siakadData = await siakadService.fetchSiakadDataWithCookie();
      _navigateToProfile(siakadData);
    } catch (e) {
      debugPrint('[AuthCheck] Cookie/Moodle login failed: $e. Navigating to SSO.');
      _navigateToSsoPage();
    }
  }

  void _navigateToProfile(SiakadData siakadData) {
    if (!mounted) return;
    sendDataToWidget(siakadData.schedule).then((_) {
      HomeWidget.updateWidget(name: 'ScheduleWidgetProvider', iOSName: 'ScheduleWidgetProvider');
    });
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ProfilePage(siakadData: siakadData, moodleService: _moodleService)),
    );
  }

  void _navigateToSsoPage() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SsoPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
