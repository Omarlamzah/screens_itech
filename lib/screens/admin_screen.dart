import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../widgets/app_toast.dart';
import 'login_screen.dart';
import 'room_control_screen.dart';
import 'event_screens_screen.dart';
import 'display_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<dynamic> _events = [];
  bool _loading = true;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await ApiService.getUser();
      final events = await ApiService.getEvents();
      setState(() { _events = events; _userName = user['name'] as String?; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      // Session expired — go to login and let it auto-re-login or show form.
      // Use pushReplacement so back still goes to the previous page (SetupScreen),
      // not back to this broken AdminScreen.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Future<void> _logout() async {
    await ApiService.logout();
    await ApiService.clearCredentials();
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0d12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f1219),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Admin Panel', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [
          if (_userName != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(child: Text(_userName!, style: const TextStyle(color: Color(0xFF9ca3af), fontSize: 13))),
            ),
          IconButton(icon: const Icon(Icons.logout, size: 20), onPressed: _logout, tooltip: 'Logout'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366f1)))
          : _events.isEmpty
              ? const Center(child: Text('No events', style: TextStyle(color: Color(0xFF6b7280))))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFF6366f1),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _events.length,
                    itemBuilder: (_, i) {
                      final e = _events[i] as Map<String, dynamic>;
                      final isActive = e['is_active'] == true;
                      return _EventCard(event: e, isActive: isActive);
                    },
                  ),
                ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool isActive;
  const _EventCard({required this.event, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0f1219),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isActive ? const Color(0xFF10b981).withValues(alpha: 0.3) : Colors.white10),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF064e3b) : const Color(0xFF1a1f2e),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.event, color: isActive ? const Color(0xFF10b981) : const Color(0xFF6b7280), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(event['name'] as String? ?? '', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF064e3b) : const Color(0xFF1f2937),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(isActive ? 'Active' : 'Inactive',
                    style: TextStyle(color: isActive ? const Color(0xFF10b981) : const Color(0xFF6b7280), fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ]),
            ])),
          ]),
        ),
        const Divider(height: 1, color: Colors.white10),
        Row(children: [
          _ActionBtn(icon: Icons.tv, label: 'Screens', onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => EventScreensScreen(eventId: event['id'] as int, eventName: event['name'] as String? ?? '')))),
          const VerticalDivider(width: 1, color: Colors.white10),
          _ActionBtn(icon: Icons.mic, label: 'Pulpits', onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => EventPulpitsScreen(eventId: event['id'] as int, eventName: event['name'] as String? ?? '')))),
          const VerticalDivider(width: 1, color: Colors.white10),
          _ActionBtn(icon: Icons.tablet_android, label: 'iPads', onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => EventRoomsScreen(eventId: event['id'] as int, eventName: event['name'] as String? ?? '')))),
        ]),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: const Color(0xFF6366f1), size: 18),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Color(0xFF818cf8), fontSize: 13, fontWeight: FontWeight.w500)),
        ]),
      ),
    ),
  );
}

// ─── Rooms list for event ───────────────────────────────────────────────────
class EventRoomsScreen extends StatefulWidget {
  final int eventId;
  final String eventName;
  const EventRoomsScreen({super.key, required this.eventId, required this.eventName});
  @override
  State<EventRoomsScreen> createState() => _EventRoomsScreenState();
}

class _EventRoomsScreenState extends State<EventRoomsScreen> {
  List<dynamic> _rooms = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final rooms = await ApiService.getRooms(widget.eventId);
      setState(() { _rooms = rooms; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0d12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f1219),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.eventName, style: const TextStyle(fontSize: 16)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.white10),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366f1)))
          : _rooms.isEmpty
              ? const Center(child: Text('No rooms', style: TextStyle(color: Color(0xFF6b7280))))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFF6366f1),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _rooms.length,
                    itemBuilder: (_, i) {
                      final r = _rooms[i] as Map<String, dynamic>;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        tileColor: const Color(0xFF0f1219),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Colors.white10)),
                        leading: const Icon(Icons.meeting_room_outlined, color: Color(0xFF6366f1)),
                        title: Text(r['name'] as String? ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                        trailing: const Icon(Icons.chevron_right, color: Color(0xFF6b7280)),
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => RoomControlScreen(roomId: r['id'] as int, roomName: r['name'] as String? ?? '', eventId: widget.eventId))),
                      );
                    },
                  ),
                ),
    );
  }
}

// ─── Pulpits list for event ─────────────────────────────────────────────────
class EventPulpitsScreen extends StatefulWidget {
  final int eventId;
  final String eventName;
  const EventPulpitsScreen({super.key, required this.eventId, required this.eventName});
  @override
  State<EventPulpitsScreen> createState() => _EventPulpitsScreenState();
}

class _EventPulpitsScreenState extends State<EventPulpitsScreen> {
  List<dynamic> _pulpits = [];
  List<dynamic> _slides  = [];
  bool _loading  = true;
  int? _pushing;
  int? _clearing;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final pulpits = await ApiService.getPulpits(widget.eventId);
      final slides  = await ApiService.getSlides(widget.eventId);
      setState(() { _pulpits = pulpits; _slides = slides; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _push(int pulpitId, int slideId) async {
    setState(() => _pushing = pulpitId);
    try {
      await ApiService.pushToPulpit(pulpitId, slideId);
      if (!mounted) return;
      AppToast.show(context, message: 'Pushed to pulpit!', type: ToastType.success, withSound: true);
    } catch (_) {
      if (!mounted) return;
      AppToast.show(context, message: 'Push failed', type: ToastType.error, withSound: true);
    } finally { setState(() => _pushing = null); }
  }

  Future<void> _clear(int pulpitId) async {
    setState(() => _clearing = pulpitId);
    try {
      await ApiService.clearPulpit(pulpitId);
      if (!mounted) return;
      AppToast.show(context, message: 'Cleared', type: ToastType.info);
    } catch (_) {} finally { setState(() => _clearing = null); }
  }

  void _showSlidePicker(Map<String, dynamic> pulpit) {
    final active = _slides.where((s) => s['is_active'] == true).toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0f1219),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [
            const Icon(Icons.mic, color: Color(0xFF6366f1), size: 18),
            const SizedBox(width: 8),
            Text('Push to ${pulpit['name']}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          ])),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: active.length,
              itemBuilder: (_, i) {
                final s = active[i] as Map<String, dynamic>;
                return ListTile(
                  leading: Container(
                    width: 44, height: 32,
                    decoration: BoxDecoration(color: const Color(0xFF1a1f2e), borderRadius: BorderRadius.circular(6)),
                    child: s['type'] == 'video'
                        ? const Icon(Icons.play_circle_outline, color: Color(0xFF6366f1), size: 20)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: s['image_url'] != null
                                ? Image.network(s['image_url'] as String, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image, color: Color(0xFF6b7280), size: 18))
                                : const Icon(Icons.image, color: Color(0xFF6b7280), size: 18),
                          ),
                  ),
                  title: Text(s['title'] as String? ?? 'Untitled', style: const TextStyle(color: Colors.white, fontSize: 14)),
                  onTap: () { Navigator.pop(context); _push(pulpit['id'] as int, s['id'] as int); },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0d12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f1219),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.eventName, style: const TextStyle(fontSize: 16)),
        actions: [IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366f1)))
          : _pulpits.isEmpty
              ? const Center(child: Text('No pulpits', style: TextStyle(color: Color(0xFF6b7280))))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFF6366f1),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pulpits.length,
                    itemBuilder: (_, i) {
                      final p = _pulpits[i] as Map<String, dynamic>;
                      final lastSeen = p['last_seen_at'] as String?;
                      final isOnline = lastSeen != null &&
                          DateTime.now().difference(DateTime.parse(lastSeen)).inSeconds < 35;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0f1219),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isOnline ? const Color(0xFF10b981).withValues(alpha: 0.3) : Colors.white10),
                        ),
                        child: Column(children: [
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: isOnline ? const Color(0xFF10b981) : const Color(0xFF4b5563))),
                              const SizedBox(width: 8),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(p['name'] as String? ?? '', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                                Text('/pulpit?n=${p['slug']}', style: const TextStyle(color: Color(0xFF6b7280), fontSize: 11, fontFamily: 'monospace')),
                              ])),
                              if (isOnline) Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFF064e3b), borderRadius: BorderRadius.circular(20)),
                                child: const Text('LIVE', style: TextStyle(color: Color(0xFF10b981), fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ]),
                          ),
                          const Divider(height: 1, color: Colors.white10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(children: [
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: _pushing == p['id'] ? null : () => _showSlidePicker(p),
                                  icon: _pushing == p['id']
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.bolt, size: 16),
                                  label: const Text('Push slide', style: TextStyle(fontSize: 13)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1e1b4b),
                                    foregroundColor: const Color(0xFF818cf8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: _clearing == p['id'] ? null : () => _clear(p['id'] as int),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFf87171),
                                  side: const BorderSide(color: Color(0xFF7f1d1d), width: 0.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                                ),
                                child: _clearing == p['id']
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFf87171)))
                                    : const Icon(Icons.close, size: 16),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final prefs = await SharedPreferences.getInstance();
                                  final frontend = (prefs.getString('frontend_url') ?? '').replaceAll(RegExp(r'/$'), '');
                                  if (!context.mounted) return;
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => DisplayScreen(
                                    url: '$frontend/pulpit?n=${p['slug']}',
                                    mode: 'pulpit',
                                    name: p['slug'] as String? ?? '',
                                  )));
                                },
                                icon: const Icon(Icons.open_in_new, size: 14),
                                label: const Text('View', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF6b7280),
                                  side: const BorderSide(color: Colors.white12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                                ),
                              ),
                            ]),
                          ),
                        ]),
                      );
                    },
                  ),
                ),
    );
  }
}
