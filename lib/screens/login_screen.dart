import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'admin_screen.dart';

const _bg         = Color(0xFF080b10);
const _surface    = Color(0xFF0d1117);
const _border     = Color(0x14FFFFFF);
const _indigo     = Color(0xFF6366f1);
const _indigoSoft = Color(0xFF818cf8);
const _gray500    = Color(0xFF6b7280);
const _gray600    = Color(0xFF4b5563);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _serverCtrl = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  bool  _loading     = false;
  bool  _autoLogging = false;
  bool  _checking    = true;   // true while verifying existing token
  bool  _obscure    = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final url   = await ApiService.getBaseUrl();
    final creds = await ApiService.getSavedCredentials();
    if (!mounted) return;
    setState(() {
      _serverCtrl.text = url;
      if (creds['email'] != null)    _emailCtrl.text = creds['email']!;
      if (creds['password'] != null) _passCtrl.text  = creds['password']!;
    });

    // 1. Check if the existing token is still valid — skip login entirely if so
    try {
      await ApiService.getUser();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminScreen()));
      return;
    } catch (_) {
      // Token missing or expired — fall through
    }

    if (!mounted) return;
    setState(() => _checking = false);

    // 2. Try silent re-login with saved credentials
    if (creds['email'] != null && creds['password'] != null) {
      setState(() => _autoLogging = true);
      await _login(auto: true);
    }
  }

  Future<void> _login({bool auto = false}) async {
    if (_serverCtrl.text.trim().isEmpty) {
      setState(() { _error = 'Enter server URL'; _autoLogging = false; });
      return;
    }
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() { _error = 'Enter email and password'; _autoLogging = false; });
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ApiService.setBaseUrl(_serverCtrl.text.trim());
      await ApiService.login(_emailCtrl.text.trim(), _passCtrl.text);
      await ApiService.saveCredentials(_emailCtrl.text.trim(), _passCtrl.text);
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminScreen()));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = auto
            ? 'Auto-login failed — please sign in manually'
            : e.toString().replaceFirst('Exception: ', '');
        _loading    = false;
        _autoLogging = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a plain dark loader while checking the existing token
    if (_checking) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _indigo)),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_hero.jpg',
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.72),
              colorBlendMode: BlendMode.darken,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.4,
                  colors: [Colors.transparent, _bg.withOpacity(0.55)],
                ),
              ),
            ),
          ),
          // Back button
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _gray500, size: 18),
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(children: [
                    // Header
                    Container(
                      width: 110, height: 72,
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _indigo.withOpacity(0.2)),
                        boxShadow: [BoxShadow(color: _indigo.withOpacity(0.18), blurRadius: 28, spreadRadius: 4)],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                    ),
                    const SizedBox(height: 18),
                    const Text('Admin Panel',
                      style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: -0.4),
                    ),
                    const SizedBox(height: 4),
                    const Text('Sign in to your account',
                      style: TextStyle(color: _gray500, fontSize: 14),
                    ),
                    const SizedBox(height: 32),

                    // Auto-login indicator
                    if (_autoLogging) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: const Color(0x1A6366f1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0x336366f1)),
                        ),
                        child: const Row(children: [
                          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _indigo)),
                          SizedBox(width: 10),
                          Text('Signing in…', style: TextStyle(color: _indigoSoft, fontSize: 13)),
                        ]),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Form card
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: _surface.withOpacity(0.88),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _border),
                      ),
                      child: Column(children: [
                        if (_error != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: const Color(0x1Af87171),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0x33f87171)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFf87171), size: 16),
                              const SizedBox(width: 10),
                              Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFf87171), fontSize: 13))),
                            ]),
                          ),
                          const SizedBox(height: 16),
                        ],
                        _field(_serverCtrl, 'Server URL',  Icons.dns_outlined,      TextInputType.url),
                        const SizedBox(height: 12),
                        _field(_emailCtrl,  'Email',        Icons.email_outlined,    TextInputType.emailAddress),
                        const SizedBox(height: 12),
                        _field(_passCtrl,   'Password',     Icons.lock_outline_rounded, TextInputType.visiblePassword,
                          obscure: _obscure,
                          toggle: () => setState(() => _obscure = !_obscure),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity, height: 52,
                          child: ElevatedButton(
                            onPressed: _loading ? null : () => _login(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _indigo,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFF1e1b4b),
                              disabledForegroundColor: const Color(0xFF4b5580),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                              elevation: 0,
                            ),
                            child: _loading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Sign In', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, IconData icon, TextInputType type,
      {bool obscure = false, VoidCallback? toggle}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      autocorrect: false,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _gray600, fontSize: 14),
        prefixIcon: Icon(icon, color: _gray500, size: 18),
        suffixIcon: toggle != null
            ? IconButton(
                icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: _gray500, size: 18),
                onPressed: toggle,
              )
            : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        border:        OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0x996366f1))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
