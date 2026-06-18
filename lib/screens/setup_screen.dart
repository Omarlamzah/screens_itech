import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'admin_screen.dart';
import 'display_screen.dart';
import 'login_screen.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _bg         = Color(0xFF080b10);
const _surface    = Color(0xFF0d1117);
const _border     = Color(0x14FFFFFF); // white/8
const _indigo     = Color(0xFF6366f1);
const _indigoSoft = Color(0xFF818cf8);
const _gray400    = Color(0xFF9ca3af);
const _gray500    = Color(0xFF6b7280);
const _gray600    = Color(0xFF4b5563);

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _serverCtrl   = TextEditingController();
  final _frontendCtrl = TextEditingController();

  String _mode = 'screen'; // 'screen' | 'ipad' | 'pulpit'

  List<Map<String, dynamic>> _events     = [];
  int?    _eventId;

  List<Map<String, dynamic>> _screens    = [];
  int?    _screenId;
  String? _screenSlug;
  String? _screenName;

  List<Map<String, dynamic>> _rooms      = [];
  int?    _roomId;
  List<Map<String, dynamic>> _nameplates = [];
  int?    _nameplateId;
  String? _nameplateSlug;
  String? _nameplateName;

  List<Map<String, dynamic>> _pulpits    = [];
  int?    _pulpitId;
  String? _pulpitSlug;
  String? _pulpitName;

  bool    _loadingEvents     = false;
  bool    _loadingScreens    = false;
  bool    _loadingRooms      = false;
  bool    _loadingNameplates = false;
  bool    _loadingPulpits    = false;
  bool    _connecting        = false;
  String? _error;

  static const _modeKey     = 'last_mode';
  static const _slugKey     = 'last_slug';
  static const _nameKey     = 'last_display_name';
  static const _frontendKey = 'frontend_url';

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  // ── Persistence ──────────────────────────────────────────────────────────────

  Future<void> _loadSaved() async {
    final prefs    = await SharedPreferences.getInstance();
    final apiUrl   = await ApiService.getBaseUrl();
    final frontend = prefs.getString(_frontendKey) ?? _deriveFrontend(apiUrl);
    final mode     = prefs.getString(_modeKey) ?? 'screen';
    final slug     = prefs.getString(_slugKey);
    final name     = prefs.getString(_nameKey);

    setState(() {
      _serverCtrl.text   = apiUrl;
      _frontendCtrl.text = frontend;
      _mode = mode;
    });

    if (slug != null && slug.isNotEmpty && mounted) {
      final path    = mode == 'screen' ? '/tv/?n=$slug&kiosk=1'
                    : mode == 'pulpit' ? '/pulpit/?n=$slug'
                    : '/ipad/?n=$slug';
      final display = frontend.replaceAll(RegExp(r'/$'), '');
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => DisplayScreen(url: '$display$path', mode: mode, name: name ?? slug),
      ));
      return;
    }

    _fetchEvents();
  }

  Future<void> _saveAndConnect() async {
    final slug = _mode == 'screen' ? _screenSlug
               : _mode == 'pulpit' ? _pulpitSlug
               : _nameplateSlug;
    final name = _mode == 'screen' ? _screenName
               : _mode == 'pulpit' ? _pulpitName
               : _nameplateName;
    if (slug == null || slug.isEmpty) {
      setState(() => _error = _mode == 'screen' ? 'Select a screen'
                            : _mode == 'pulpit' ? 'Select a pulpit'
                            : 'Select a nameplate');
      return;
    }
    setState(() { _connecting = true; _error = null; });
    try {
      await ApiService.setBaseUrl(_serverCtrl.text.trim());
      final prefs    = await SharedPreferences.getInstance();
      final frontend = _frontendCtrl.text.trim().replaceAll(RegExp(r'/$'), '');
      await prefs.setString(_modeKey,     _mode);
      await prefs.setString(_slugKey,     slug);
      await prefs.setString(_nameKey,     name ?? slug);
      await prefs.setString(_frontendKey, frontend);

      final path = _mode == 'screen' ? '/tv/?n=$slug&kiosk=1'
                 : _mode == 'pulpit' ? '/pulpit/?n=$slug'
                 : '/ipad/?n=$slug';
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => DisplayScreen(url: '$frontend$path', mode: _mode, name: name ?? slug),
      ));
    } catch (e) {
      setState(() { _error = e.toString(); _connecting = false; });
    }
  }

  // ── API fetchers ─────────────────────────────────────────────────────────────

  Future<void> _fetchEvents() async {
    final base = _serverCtrl.text.trim();
    if (base.isEmpty) return;
    setState(() {
      _loadingEvents = true;
      _events = []; _eventId = null;
      _screens = []; _screenId = null; _screenSlug = null;
      _rooms = []; _roomId = null;
      _nameplates = []; _nameplateId = null; _nameplateSlug = null;
      _pulpits = []; _pulpitId = null; _pulpitSlug = null;
      _error = null;
    });
    try {
      final res = await http.get(Uri.parse('$base/api/public/events'));
      if (res.statusCode == 200) {
        setState(() => _events = List<Map<String, dynamic>>.from(jsonDecode(res.body) as List));
      } else {
        setState(() => _error = 'Could not load events (${res.statusCode})');
      }
    } catch (_) {
      setState(() => _error = 'Cannot reach API — check the URL');
    } finally {
      setState(() => _loadingEvents = false);
    }
  }

  Future<void> _onEventSelected(int id) async {
    setState(() {
      _eventId = id;
      _screens = []; _screenId = null; _screenSlug = null;
      _rooms   = []; _roomId = null;
      _nameplates = []; _nameplateId = null; _nameplateSlug = null;
      _pulpits = []; _pulpitId = null; _pulpitSlug = null;
    });
    final base = _serverCtrl.text.trim();
    if (_mode == 'screen') {
      setState(() => _loadingScreens = true);
      try {
        final res = await http.get(Uri.parse('$base/api/public/events/$id/screens'));
        if (res.statusCode == 200) {
          setState(() => _screens = List<Map<String, dynamic>>.from(jsonDecode(res.body) as List));
        }
      } catch (_) {}
      setState(() => _loadingScreens = false);
    } else if (_mode == 'pulpit') {
      setState(() => _loadingPulpits = true);
      try {
        final res = await http.get(Uri.parse('$base/api/public/events/$id/pulpits'));
        if (res.statusCode == 200) {
          setState(() => _pulpits = List<Map<String, dynamic>>.from(jsonDecode(res.body) as List));
        }
      } catch (_) {}
      setState(() => _loadingPulpits = false);
    } else {
      setState(() => _loadingRooms = true);
      try {
        final res = await http.get(Uri.parse('$base/api/public/events/$id/rooms'));
        if (res.statusCode == 200) {
          setState(() => _rooms = List<Map<String, dynamic>>.from(jsonDecode(res.body) as List));
        }
      } catch (_) {}
      setState(() => _loadingRooms = false);
    }
  }

  Future<void> _onRoomSelected(int id) async {
    setState(() {
      _roomId = id;
      _nameplates = []; _nameplateId = null; _nameplateSlug = null;
      _loadingNameplates = true;
    });
    final base = _serverCtrl.text.trim();
    try {
      final res = await http.get(Uri.parse('$base/api/public/rooms/$id/nameplates'));
      if (res.statusCode == 200) {
        setState(() => _nameplates = List<Map<String, dynamic>>.from(jsonDecode(res.body) as List));
      }
    } catch (_) {}
    setState(() => _loadingNameplates = false);
  }

  void _onModeChanged(String mode) {
    setState(() {
      _mode = mode;
      _screens = []; _screenId = null; _screenSlug = null;
      _rooms   = []; _roomId   = null;
      _nameplates = []; _nameplateId = null; _nameplateSlug = null;
      _pulpits = []; _pulpitId = null; _pulpitSlug = null;
    });
    if (_eventId != null) _onEventSelected(_eventId!);
  }

  String _deriveFrontend(String apiUrl) {
    try {
      var url = apiUrl.trim();
      if (!url.startsWith('http://') && !url.startsWith('https://')) url = 'http://$url';
      final uri = Uri.parse(url);
      if (uri.host.isEmpty) return url;
      if (uri.port == 8000) return 'http://${uri.host}:3000';
      return '${uri.scheme}://${uri.host}';
    } catch (_) { return apiUrl; }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final canConnect = _mode == 'screen'  ? (_screenSlug != null)
                     : _mode == 'pulpit' ? (_pulpitSlug != null)
                     : (_nameplateSlug != null);

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_hero.jpg',
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.72),
              colorBlendMode: BlendMode.darken,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          // Gradient vignette
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.4,
                  colors: [Colors.transparent, _bg.withOpacity(0.6)],
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 28),

                      // ── Connection card ──────────────────────────────
                      _card(children: [
                        _sectionTitle(Icons.link_rounded, 'Connection'),
                        const SizedBox(height: 18),
                        _label('API URL (Laravel)'),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: _input(_serverCtrl, 'https://api.example.com', TextInputType.url)),
                          const SizedBox(width: 8),
                          _iconBtn(Icons.refresh_rounded, _fetchEvents, loading: _loadingEvents),
                        ]),
                        const SizedBox(height: 14),
                        _label('Display URL (Next.js)'),
                        const SizedBox(height: 8),
                        _input(_frontendCtrl, 'https://display.example.com', TextInputType.url),
                      ]),
                      const SizedBox(height: 12),

                      // ── Device type card ─────────────────────────────
                      _card(children: [
                        _sectionTitle(Icons.devices_rounded, 'Device Type'),
                        const SizedBox(height: 16),
                        Row(children: [
                          _modeBtn('screen', Icons.tv_rounded,              'Screen'),
                          const SizedBox(width: 8),
                          _modeBtn('pulpit', Icons.mic_rounded,             'Pulpit'),
                          const SizedBox(width: 8),
                          _modeBtn('ipad',   Icons.tablet_android_rounded,  'Nameplate'),
                        ]),
                      ]),
                      const SizedBox(height: 12),

                      // ── Selection card ───────────────────────────────
                      _card(children: [
                        _sectionTitle(Icons.list_alt_rounded, 'Selection'),
                        const SizedBox(height: 18),
                        _label('Event'),
                        const SizedBox(height: 8),
                        _dropdown(
                          hint: _loadingEvents ? 'Loading events…'
                              : _events.isEmpty ? 'No events — check API URL'
                              : 'Select event…',
                          items: _events,
                          value: _eventId,
                          enabled: !_loadingEvents && _events.isNotEmpty,
                          onChanged: (id) => _onEventSelected(id!),
                        ),
                        const SizedBox(height: 14),

                        if (_mode == 'screen') ...[
                          _label('Screen'),
                          const SizedBox(height: 8),
                          _dropdown(
                            hint: _loadingScreens ? 'Loading…'
                                : _eventId == null ? 'Pick an event first'
                                : _screens.isEmpty ? 'No screens in this event'
                                : 'Select screen…',
                            items: _screens,
                            value: _screenId,
                            enabled: !_loadingScreens && _screens.isNotEmpty,
                            onChanged: (id) {
                              final s = _screens.firstWhere((x) => x['id'] == id);
                              setState(() { _screenId = id; _screenSlug = s['slug'] as String?; _screenName = s['name'] as String?; });
                            },
                          ),
                        ] else if (_mode == 'pulpit') ...[
                          _label('Pulpit'),
                          const SizedBox(height: 8),
                          _dropdown(
                            hint: _loadingPulpits ? 'Loading…'
                                : _eventId == null ? 'Pick an event first'
                                : _pulpits.isEmpty ? 'No pulpits in this event'
                                : 'Select pulpit…',
                            items: _pulpits,
                            value: _pulpitId,
                            enabled: !_loadingPulpits && _pulpits.isNotEmpty,
                            onChanged: (id) {
                              final p = _pulpits.firstWhere((x) => x['id'] == id);
                              setState(() { _pulpitId = id; _pulpitSlug = p['slug'] as String?; _pulpitName = p['name'] as String?; });
                            },
                          ),
                        ] else ...[
                          _label('Room'),
                          const SizedBox(height: 8),
                          _dropdown(
                            hint: _loadingRooms ? 'Loading…'
                                : _eventId == null ? 'Pick an event first'
                                : _rooms.isEmpty ? 'No rooms in this event'
                                : 'Select room…',
                            items: _rooms,
                            value: _roomId,
                            enabled: !_loadingRooms && _rooms.isNotEmpty,
                            onChanged: (id) => _onRoomSelected(id!),
                          ),
                          const SizedBox(height: 14),
                          _label('Nameplate'),
                          const SizedBox(height: 8),
                          _dropdown(
                            hint: _loadingNameplates ? 'Loading…'
                                : _roomId == null ? 'Pick a room first'
                                : _nameplates.isEmpty ? 'No nameplates in this room'
                                : 'Select nameplate…',
                            items: _nameplates,
                            value: _nameplateId,
                            enabled: !_loadingNameplates && _nameplates.isNotEmpty,
                            onChanged: (id) {
                              final n = _nameplates.firstWhere((x) => x['id'] == id);
                              setState(() { _nameplateId = id; _nameplateSlug = n['slug'] as String?; _nameplateName = n['name'] as String?; });
                            },
                          ),
                        ],
                      ]),

                      // ── Error ────────────────────────────────────────
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0x1Af87171),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x33f87171)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFf87171), size: 16),
                            const SizedBox(width: 10),
                            Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFf87171), fontSize: 13))),
                          ]),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // ── Connect button ───────────────────────────────
                      SizedBox(
                        width: double.infinity, height: 54,
                        child: ElevatedButton(
                          onPressed: (canConnect && !_connecting) ? _saveAndConnect : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _indigo,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFF1e1b4b),
                            disabledForegroundColor: const Color(0xFF4b5580),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                            shadowColor: _indigo.withOpacity(0.4),
                          ),
                          child: _connecting
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Icon(Icons.play_circle_fill_rounded, size: 20),
                                  SizedBox(width: 10),
                                  Text('Open Display', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
                                ]),
                        ),
                      ),

                      const SizedBox(height: 20),
                      Divider(color: Colors.white.withOpacity(0.07)),
                      const SizedBox(height: 14),

                      // ── Admin link ───────────────────────────────────
                      TextButton.icon(
                        onPressed: () async {
                          try {
                            await ApiService.getUser();
                            // Token valid — go directly to admin dashboard
                            if (!context.mounted) return;
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen()));
                          } catch (_) {
                            // Not logged in — show login screen
                            if (!context.mounted) return;
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                          }
                        },
                        icon: const Icon(Icons.admin_panel_settings_outlined, size: 16, color: _gray500),
                        label: const Text('Admin panel', style: TextStyle(color: _gray500, fontSize: 13)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: Colors.white.withOpacity(0.07)),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section widgets ───────────────────────────────────────────────────────────

  Widget _buildHeader() => Column(children: [
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
    const Text('Event Display', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
    const SizedBox(height: 5),
    const Text('Display App Setup', style: TextStyle(color: _gray500, fontSize: 14, letterSpacing: 0.1)),
  ]);

  Widget _card({required List<Widget> children}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _surface.withOpacity(0.88),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );

  Widget _sectionTitle(IconData icon, String title) => Row(children: [
    Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: _indigo.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _indigo.withOpacity(0.22)),
      ),
      child: Icon(icon, color: _indigoSoft, size: 14),
    ),
    const SizedBox(width: 10),
    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5, letterSpacing: 0.1)),
  ]);

  // ── Field helpers ─────────────────────────────────────────────────────────────

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(color: _gray400, fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.6),
  );

  Widget _input(TextEditingController ctrl, String hint, TextInputType type) => TextField(
    controller: ctrl,
    keyboardType: type,
    autocorrect: false,
    style: const TextStyle(color: Colors.white, fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _gray600, fontSize: 14),
      filled: true,
      fillColor: Colors.white.withOpacity(0.04),
      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0x99_6366f1))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
  );

  Widget _iconBtn(IconData icon, VoidCallback onTap, {bool loading = false}) => SizedBox(
    width: 48, height: 50,
    child: Material(
      color: Colors.white.withOpacity(0.04),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: loading ? null : onTap,
        child: Center(
          child: loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _indigo))
              : Icon(icon, color: _indigo, size: 22),
        ),
      ),
    ),
  );

  Widget _dropdown({
    required String hint,
    required List<Map<String, dynamic>> items,
    required int? value,
    required bool enabled,
    required ValueChanged<int?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButton<int>(
        value: value,
        onChanged: enabled ? onChanged : null,
        isExpanded: true,
        dropdownColor: const Color(0xFF13171f),
        underline: const SizedBox.shrink(),
        icon: const Icon(Icons.expand_more_rounded, color: _gray500, size: 20),
        hint: Text(hint, style: const TextStyle(color: _gray600, fontSize: 14)),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        items: items.map((item) => DropdownMenuItem<int>(
          value: item['id'] as int,
          child: Text(item['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 14)),
        )).toList(),
      ),
    );
  }

  Widget _modeBtn(String value, IconData icon, String label) {
    final selected = _mode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onModeChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? _indigo.withOpacity(0.14) : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _indigo.withOpacity(0.5) : Colors.white.withOpacity(0.08),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(children: [
            Icon(icon,
              color: selected ? _indigoSoft : _gray600,
              size: 26,
            ),
            const SizedBox(height: 7),
            Text(label,
              style: TextStyle(
                color: selected ? _indigoSoft : _gray500,
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      ),
    );
  }
}
