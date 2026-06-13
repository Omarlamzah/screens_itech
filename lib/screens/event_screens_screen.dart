import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/app_toast.dart';
import 'display_screen.dart';
import 'screen_control_screen.dart';

class EventScreensScreen extends StatefulWidget {
  final int eventId;
  final String eventName;
  const EventScreensScreen({super.key, required this.eventId, required this.eventName});
  @override
  State<EventScreensScreen> createState() => _EventScreensScreenState();
}

class _EventScreensScreenState extends State<EventScreensScreen> {
  List<dynamic> _screens = [];
  List<dynamic> _slides = [];
  bool _loading = true;
  int? _pushing;
  int? _clearing;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final screens = await ApiService.getScreens(widget.eventId);
      final slides = await ApiService.getSlides(widget.eventId);
      setState(() { _screens = screens; _slides = slides; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _push(int screenId, int slideId) async {
    setState(() => _pushing = screenId);
    try {
      await ApiService.pushToScreen(screenId, slideId);
      if (!mounted) return;
      AppToast.show(context, message: 'Pushed to screen!', type: ToastType.success, withSound: true);
    } catch (_) {
      if (!mounted) return;
      AppToast.show(context, message: 'Push failed', type: ToastType.error, withSound: true);
    } finally { setState(() => _pushing = null); }
  }

  Future<void> _clear(int screenId) async {
    setState(() => _clearing = screenId);
    try {
      await ApiService.clearScreen(screenId);
      if (!mounted) return;
      AppToast.show(context, message: 'Cleared', type: ToastType.info);
    } catch (_) {} finally { setState(() => _clearing = null); }
  }

  void _showSlidePicker(Map<String, dynamic> screen) {
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
            const Icon(Icons.tv, color: Color(0xFF6366f1), size: 18),
            const SizedBox(width: 8),
            Text('Push to ${screen['name']}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
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
                  onTap: () { Navigator.pop(context); _push(screen['id'] as int, s['id'] as int); },
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
          : _screens.isEmpty
              ? const Center(child: Text('No screens', style: TextStyle(color: Color(0xFF6b7280))))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFF6366f1),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _screens.length,
                    itemBuilder: (_, i) {
                      final s = _screens[i] as Map<String, dynamic>;
                      final lastSeen = s['last_seen_at'] as String?;
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
                          InkWell(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ScreenControlScreen(
                                screenId: s['id'] as int,
                                screenName: s['name'] as String? ?? 'Screen',
                                eventId: widget.eventId,
                              )),
                            ),
                            child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: isOnline ? const Color(0xFF10b981) : const Color(0xFF4b5563))),
                              const SizedBox(width: 8),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(s['name'] as String? ?? '', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                                Text('/tv?n=${s['slug']}', style: const TextStyle(color: Color(0xFF6b7280), fontSize: 11, fontFamily: 'monospace')),
                              ])),
                              if (isOnline) Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(color: const Color(0xFF064e3b), borderRadius: BorderRadius.circular(20)),
                                child: const Text('LIVE', style: TextStyle(color: Color(0xFF10b981), fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.chevron_right, color: Color(0xFF4b5563), size: 18),
                            ]),
                          ),
                          ),
                          const Divider(height: 1, color: Colors.white10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(children: [
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: _pushing == s['id'] ? null : () => _showSlidePicker(s),
                                  icon: _pushing == s['id']
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
                                onPressed: _clearing == s['id'] ? null : () => _clear(s['id'] as int),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFf87171),
                                  side: const BorderSide(color: Color(0xFF7f1d1d), width: 0.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                                ),
                                child: _clearing == s['id']
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFf87171)))
                                    : const Icon(Icons.close, size: 16),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final base = await ApiService.getBaseUrl();
                                  if (!context.mounted) return;
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => DisplayScreen(
                                    url: '$base/tv?n=${s['slug']}',
                                    mode: 'screen',
                                    name: s['slug'] as String? ?? '',
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
