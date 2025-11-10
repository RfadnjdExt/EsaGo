import 'package:flutter/material.dart';

class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      backgroundColor: Colors.grey[200],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Header Tabs
                    const _HeaderTabs(),
                    const SizedBox(height: 24),
                    // Logo
                    Image.asset('assets/logo.png', height: 60),
                    const SizedBox(height: 24),
                    // Success Message Box
                    const _InfoBox(
                      message: 'Email a password reset link',
                      color: Color(0xFFDFF0D8),
                      icon: Icons.check_circle,
                      iconColor: Color(0xFF3C763D),
                    ),
                    const SizedBox(height: 16),
                    // Info Message Box
                    const _InfoBox(
                      message: 'Tuliskan username (NIP, NIM, atau Nomor Dosen) dan alamat email. Kemudian klik tautan yang terdapat pada email yang dikirim.',
                      color: Color(0xFFFCF8E3),
                      icon: Icons.info,
                      iconColor: Color(0xFF8A6D3B),
                    ),
                    const SizedBox(height: 24),
                    // Form Box
                    Container(
                      padding: const EdgeInsets.all(24.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9EDF7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBCE8F1)),
                      ),
                      child: Column(
                        children: [
                          // Username Field
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.person),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Mail Field
                          TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Mail',
                              prefixIcon: Icon(Icons.email),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Send Button
                          ElevatedButton.icon(
                            icon: const Icon(Icons.send, size: 18),
                            label: const Text('Send'),
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5CB85C),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderTabs extends StatelessWidget {
  const _HeaderTabs();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Tab(icon: Icons.lock_reset, text: 'Reset Password (Remember Old Password)'),
        ),
        Container(height: 40, width: 1, color: Colors.grey[300]),
        const Expanded(
          child: Tab(
            icon: Icons.email_outlined,
            text: 'Email (Lost Old Password)',
            isActive: true, // Make this tab look active
          ),
        ),
      ],
    );
  }
}

class Tab extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isActive;

  const Tab({required this.icon, required this.text, this.isActive = false, super.key});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.blue[700] : Colors.grey[600];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? Colors.grey[100] : Colors.transparent,
        border: Border(bottom: BorderSide(color: isActive ? Colors.blue[700]! : Colors.transparent, width: 2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600), softWrap: true,)),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String message;
  final Color color;
  final IconData icon;
  final Color iconColor;

  const _InfoBox({required this.message, required this.color, required this.icon, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(204)), // 0.8 opacity
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: TextStyle(color: iconColor))), 
        ],
      ),
    );
  }
}
