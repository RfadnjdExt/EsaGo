import 'dart:async';
import 'package:esago/forgot_password_page.dart';
import 'package:esago/models/siakad_data.dart';
import 'package:esago/profile_page.dart';
import 'package:esago/services/moodle_service.dart';
import 'package:esago/services/service_status_service.dart';
import 'package:esago/services/siakad_service.dart';
import 'package:esago/widget_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SsoPage extends StatelessWidget {
  const SsoPage({super.key});

  @override
  Widget build(BuildContext context) {
    Future<void> _handleRefresh() async {
      await context.read<ServiceStatusService>().checkAllServices();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A1931),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        backgroundColor: const Color(0xFF183A5D),
        color: Colors.orange,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: const _SsoFormContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SsoFormContent extends StatefulWidget {
  const _SsoFormContent();

  @override
  State<_SsoFormContent> createState() => _SsoFormContentState();
}

class _SsoFormContentState extends State<_SsoFormContent> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  late final MoodleService _moodleService;
  late final SiakadService _siakadService;

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _canLogin = false;

  @override
  void initState() {
    super.initState();
    final serviceStatusService = context.read<ServiceStatusService>();
    _moodleService = MoodleService(serviceStatusService: serviceStatusService);
    _siakadService = SiakadService(_moodleService);

    _usernameController.addListener(_updateCanLoginState);
    _passwordController.addListener(_updateCanLoginState);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _updateCanLoginState() {
    setState(() {
      _canLogin = _usernameController.text.isNotEmpty && _passwordController.text.isNotEmpty;
    });
  }

  Future<void> _login() async {
    if (_isLoading || !_canLogin) return;

    setState(() {
      _isLoading = true;
    });

    final statusService = context.read<ServiceStatusService>();
    final String username = _usernameController.text;
    final String password = _passwordController.text;
    SiakadData? siakadData;

    try {
      // 1. Cek ulang status semua layanan untuk data terbaru
      await statusService.checkAllServices();
      if (!mounted) return;

      // 2. Coba login Moodle jika statusnya online
      if (statusService.isElearningOnline) {
        try {
          await _moodleService.login(username, password);
        } catch (moodleError) {
          // Abaikan error Moodle, cukup catat dan lanjutkan
          debugPrint("Moodle login failed but proceeding: $moodleError");
        }
      }

      // 3. Coba login via SSO jika statusnya online
      if (statusService.ssoStatus == ServiceStatus.online) {
        try {
          siakadData = await _siakadService.loginSsoAndFetchData(username, password);
        } catch (ssoError) {
          debugPrint("SSO login failed: $ssoError. Fallback to Siakad.");
        }
      }

      // 4. Fallback ke Siakad jika data belum didapat
      if (siakadData == null) {
        siakadData = await _siakadService.fetchSiakadData(username, password);
      }

      // 5. Jika masih gagal, berarti login memang tidak berhasil
      if (siakadData == null) {
        throw Exception('Login gagal. Periksa kembali NIM dan password Anda.');
      }

      await _saveCredentials();
      await sendDataToWidget(siakadData.schedule);

      if (mounted) {
        _navigateToProfile(siakadData);
      }

    } on TimeoutException {
      _showErrorDialog('Waktu koneksi habis. Periksa internet Anda.');
    } catch (e) {
      _showErrorDialog(e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nim', _usernameController.text);
    await prefs.setString('password', _passwordController.text);
  }

  void _navigateToProfile(SiakadData siakadData) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(siakadData: siakadData, moodleService: _moodleService),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16),
                const Icon(Icons.cancel, color: Colors.red, size: 60),
                const SizedBox(height: 24),
                const Text('Oops', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.black54)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('OK', style: TextStyle(color: Colors.white, fontSize: 16)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          );
        });
  }

  Widget _buildStatusIndicators(ServiceStatusService statusService) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatusDot(statusService.ssoStatus, 'SSO'),
          _buildStatusDot(statusService.siakadStatus, 'SIAKAD'),
          _buildStatusDot(statusService.elearningStatus, 'E-Learning'),
        ],
      ),
    );
  }

  Widget _buildStatusDot(ServiceStatus status, String label) {
    Color color;
    switch (status) {
      case ServiceStatus.online:
        color = Colors.greenAccent;
        break;
      case ServiceStatus.offline:
        color = Colors.redAccent;
        break;
      case ServiceStatus.unknown:
      default:
        color = Colors.grey;
        break;
    }

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.5), blurRadius: 4, spreadRadius: 1),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServiceStatusService>(
      builder: (context, statusService, child) {
        return AutofillGroup(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset('assets/logo.png', height: 60, fit: BoxFit.contain),
              const SizedBox(height: 32),
              const Text('FORM MASUK', style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1.2)),
              const SizedBox(height: 8),
              const Text('Single Sign On', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Silahkan gunakan kredensial Anda untuk masuk.', style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 40),
              TextField(
                controller: _usernameController,
                autofillHints: const [AutofillHints.username],
                decoration: InputDecoration(hintText: 'NIM/Username', hintStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: const Color(0xFF183A5D), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                autofillHints: const [AutofillHints.password],
                onEditingComplete: () => TextInput.finishAutofillContext(),
                decoration: InputDecoration(
                  hintText: 'Password',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: const Color(0xFF183A5D),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white54,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading || !_canLogin ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.orange.withAlpha(128),
                  disabledForegroundColor: Colors.white.withAlpha(178),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : const Text('MASUK'),
              ),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
                    );
                  },
                  child: const Text('Lupa Password?', style: TextStyle(color: Colors.white70)),
                ),
              ),
              const SizedBox(height: 20),
              _buildStatusIndicators(statusService),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  '© ${DateTime.now().year} UNIVERSITAS ESA UNGGUL',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
