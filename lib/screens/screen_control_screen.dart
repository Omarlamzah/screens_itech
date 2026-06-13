import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/app_toast.dart';

class ScreenControlScreen extends StatefulWidget {
  final int screenId;
  final String screenName;
  final int eventId;

  const ScreenControlScreen({
    super.key,
    required this.screenId,
    required this.screenName,
    required this.eventId,
  });

  @override
  State<ScreenControlScreen> createState() => _ScreenControlScreenState();
}

class _ScreenControlScreenState extends State<ScreenControlScreen> {
  Map<String, dynamic>? _screen;
  List<dynamic> _slides = [];
  Map<String, dynamic>? _activeSlide;
  bool _loading = true;
  int? _pushing;
  bool _clearing = false;
  bool _pausing = false;
  DateTime? _activeSince;
  DateTime _now = DateTime.now();
  Timer? _pollTimer;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshCurrent());
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getScreen(widget.screenId),
        ApiService.getSlides(widget.eventId),
        ApiService.getCurrentSlide(widget.screenId),
      ]);
      if (!mounted) return;
      setState(() {
        _screen = results[0] as Map<String, dynamic>;
        _slides = results[1] as List<dynamic>;
        final current = (results[2] as Map<String, dynamic>)['slide'] as Map<String, dynamic>?;
        if (current?['id'] != _activeSlide?['id']) _activeSince = DateTime.now();
        _activeSlide = current;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshCurrent() async {
    try {
      final data = await ApiService.getCurrentSlide(widget.screenId);
      if (!mounted) return;
      final newSlide = data['slide'] as Map<String, dynamic>?;
      setState(() {
        if ((newSlide?['id']) != (_activeSlide?['id'])) _activeSince = DateTime.now();
        _activeSlide = newSlide;
        _now = DateTime.now();
      });
    } catch (_) {}
  }

  Future<void> _push(int slideId) async {
    setState(() => _pushing = slideId);
    try {
      await ApiService.pushToScreen(widget.screenId, slideId);
      final data = await ApiService.getCurrentSlide(widget.screenId);
      if (!mounted) return;
      final newSlide = data['slide'] as Map<String, dynamic>?;
      setState(() {
        if ((newSlide?['id']) != (_activeSlide?['id'])) _activeSince = DateTime.now();
        _activeSlide = newSlide;
        _screen = _screen != null ? {..._screen!, 'current_slide_id': slideId} : _screen;
      });
      final slide = _slides.firstWhere((s) => s['id'] == slideId, orElse: () => <String, dynamic>{});
      AppToast.show(context, message: '"${slide['title'] ?? 'Slide'}" pushed', type: ToastType.success, withSound: true);
    } catch (_) {
      if (!mounted) return;
      AppToast.show(context, message: 'Push failed', type: ToastType.error, withSound: true);
    } finally {
      if (mounted) setState(() => _pushing = null);
    }
  }

  Future<void> _pause() async {
    final active = _activeSlide;
    if (active == null) return;
    setState(() => _pausing = true);
    try {
      await ApiService.pushToScreen(widget.screenId, active['id'] as int);
      if (!mounted) return;
      setState(() => _screen = _screen != null ? {..._screen!, 'current_slide_id': active['id']} : _screen);
      AppToast.show(context, message: 'Schedule paused', type: ToastType.info);
    } catch (_) {
      if (!mounted) return;
      AppToast.show(context, message: 'Pause failed', type: ToastType.error, withSound: true);
    } finally {
      if (mounted) setState(() => _pausing = false);
    }
  }

  Future<void> _resume() async {
    setState(() => _clearing = true);
    try {
      await ApiService.clearScreen(widget.screenId);
      final data = await ApiService.getCurrentSlide(widget.screenId);
      if (!mounted) return;
      setState(() {
        _activeSlide = data['slide'] as Map<String, dynamic>?;
        _activeSince = DateTime.now();
        _screen = _screen != null
            ? {..._screen!, 'current_slide_id': null, 'override_expires_at': null}
            : _screen;
      });
      AppToast.show(context, message: 'Schedule resumed', type: ToastType.success);
    } catch (_) {
      if (!mounted) return;
      AppToast.show(context, message: 'Resume failed', type: ToastType.error, withSound: true);
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  int _toMin(String? hhmm) {
    if (hhmm == null) return -1;
    final parts = hhmm.split(':');
    if (parts.length < 2) return -1;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return -1;
    return h * 60 + m;
  }

  String _fmtTime(String? t) {
    if (t == null) return '';
    final parts = t.split(':');
    return parts.length >= 2 ? '${parts[0]}:${parts[1]}' : t;
  }

  String _fmtDiff(int minutes) {
    if (minutes < 1) return '< 1min';
    final h = minutes ~/ 60, m = minutes % 60;
    if (h == 0) return '${m}min';
    if (m == 0) return '${h}h';
    return '${h}h ${m}min';
  }

  String _fmtOverrideTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso.length >= 16 ? iso.substring(11, 16) : iso;
    }
  }

  List<Map<String, dynamic>> get _scheduledSlides {
    return _slides
        .where((s) => s['is_active'] == true && s['start_time'] != null && s['end_time'] != null)
        .map((s) => s as Map<String, dynamic>)
        .toList()
      ..sort((a, b) => _toMin(a['start_time']) - _toMin(b['start_time']));
  }

  Map<String, dynamic>? get _scheduledNow {
    final nowMin = _now.hour * 60 + _now.minute;
    try {
      return _scheduledSlides.firstWhere(
        (s) => _toMin(s['start_time']) <= nowMin && _toMin(s['end_time']) > nowMin,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? get _nextScheduledSlide {
    final nowMin = _now.hour * 60 + _now.minute;
    try {
      return _scheduledSlides.firstWhere((s) => _toMin(s['start_time']) > nowMin);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = _screen?['is_active'] == true;
    final hasOverride = _screen?['current_slide_id'] != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0a0d12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f1219),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(children: [
          Expanded(
            child: Text(widget.screenName, style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isOnline ? const Color(0xFF022c22) : const Color(0xFF1f2937),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline ? const Color(0xFF10b981) : const Color(0xFF4b5563),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  color: isOnline ? const Color(0xFF10b981) : const Color(0xFF6b7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          ),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366f1)))
          : RefreshIndicator(
              onRefresh: _load,
              color: const Color(0xFF6366f1),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Slug
                  if (_screen?['slug'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        '/tv?n=${_screen!['slug']}',
                        style: const TextStyle(color: Color(0xFF4b5563), fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ),
                  _buildActiveSlideCard(),
                  const SizedBox(height: 12),
                  if (_scheduledSlides.isNotEmpty) ...[
                    _buildScheduleCard(),
                    const SizedBox(height: 12),
                  ],
                  _buildOverrideCard(hasOverride),
                  const SizedBox(height: 20),
                  _buildSlideGrid(),
                  if (_scheduledSlides.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildTimeline(),
                  ],
                  const SizedBox(height: 20),
                ]),
              ),
            ),
    );
  }

  Widget _buildActiveSlideCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0f1219),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(children: [
            const Text(
              'NOW DISPLAYING',
              style: TextStyle(color: Color(0xFF6b7280), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2),
            ),
            const Spacer(),
            if (_screen?['width'] != null && _screen?['height'] != null)
              Text(
                '${_screen!['width']} × ${_screen!['height']}',
                style: const TextStyle(color: Color(0xFF4b5563), fontSize: 10, fontFamily: 'monospace'),
              )
            else
              const Text(
                'no display connected',
                style: TextStyle(color: Color(0xFF374151), fontSize: 10, fontStyle: FontStyle.italic),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: AspectRatio(
            aspectRatio: () {
              final w = _screen?['width'];
              final h = _screen?['height'];
              if (w != null && h != null && h != 0) return (w as num) / (h as num);
              return 16.0 / 9.0;
            }(),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _activeSlide != null && _activeSlide!['type'] == 'video'
                  ? Container(
                      color: const Color(0xFF1a1f2e),
                      child: const Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.play_circle_outline, color: Color(0xFF6366f1), size: 36),
                          SizedBox(height: 6),
                          Text('Video slide', style: TextStyle(color: Color(0xFF6b7280), fontSize: 11)),
                        ]),
                      ),
                    )
                  : _activeSlide?['image_url'] != null
                      ? Image.network(
                          _activeSlide!['image_url'] as String,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _noSlidePlaceholder(),
                        )
                      : _noSlidePlaceholder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: _activeSlide != null
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    _activeSlide!['title'] as String? ?? 'Untitled',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(children: [
                    if (_activeSince != null) ...[
                      Icon(Icons.access_time, size: 11, color: Colors.white.withValues(alpha: 0.3)),
                      const SizedBox(width: 4),
                      Text(
                        'On screen ${_fmtDiff(_now.difference(_activeSince!).inMinutes)}',
                        style: const TextStyle(color: Color(0xFF6b7280), fontSize: 11),
                      ),
                    ],
                    if (_activeSlide!['start_time'] != null) ...[
                      const SizedBox(width: 10),
                      Text(
                        '${_fmtTime(_activeSlide!['start_time'])} – ${_fmtTime(_activeSlide!['end_time'])}',
                        style: const TextStyle(color: Color(0xFF4b5563), fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ],
                  ]),
                ])
              : const Text('Nothing is being displayed', style: TextStyle(color: Color(0xFF4b5563), fontSize: 12)),
        ),
      ]),
    );
  }

  Widget _noSlidePlaceholder() {
    return Container(
      color: const Color(0xFF1a1f2e),
      child: const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.monitor, color: Color(0xFF374151), size: 32),
          SizedBox(height: 6),
          Text('No slide on screen', style: TextStyle(color: Color(0xFF374151), fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _buildScheduleCard() {
    final nowMin = _now.hour * 60 + _now.minute;
    final now = _scheduledNow;
    final next = _nextScheduledSlide;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0f1219),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text(
            'SCHEDULE',
            style: TextStyle(color: Color(0xFF6b7280), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2),
          ),
          const Spacer(),
          Text(
            '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(color: Color(0xFF4b5563), fontSize: 11, fontFamily: 'monospace'),
          ),
        ]),
        const SizedBox(height: 10),
        if (now != null)
          _scheduleRow(
            label: now['title'] as String? ?? 'Untitled',
            badge: '−${_fmtDiff(_toMin(now['end_time']) - nowMin)}',
            badgeColor: const Color(0xFF10b981),
            bgColor: const Color(0xFF022c22),
            dotColor: const Color(0xFF10b981),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('No slide right now', style: TextStyle(color: Color(0xFF4b5563), fontSize: 12)),
          ),
        if (next != null) ...[
          const SizedBox(height: 6),
          _scheduleRow(
            label: next['title'] as String? ?? 'Untitled',
            badge: 'in ${_fmtDiff(_toMin(next['start_time']) - nowMin)}',
            badgeColor: const Color(0xFF38bdf8),
            bgColor: const Color(0xFF082f49),
            dotColor: const Color(0xFF38bdf8),
            icon: Icons.skip_next,
          ),
        ],
      ]),
    );
  }

  Widget _scheduleRow({
    required String label,
    required String badge,
    required Color badgeColor,
    required Color bgColor,
    required Color dotColor,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        if (icon != null)
          Icon(icon, color: dotColor, size: 13)
        else
          Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          badge,
          style: TextStyle(color: badgeColor.withValues(alpha: 0.7), fontSize: 11, fontFamily: 'monospace'),
        ),
      ]),
    );
  }

  Widget _buildOverrideCard(bool hasOverride) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0f1219),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text(
            'OVERRIDE',
            style: TextStyle(color: Color(0xFF6b7280), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: hasOverride ? const Color(0xFF451a03) : const Color(0xFF022c22),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasOverride ? const Color(0xFFf59e0b) : const Color(0xFF10b981),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                hasOverride ? 'Paused' : 'Running',
                style: TextStyle(
                  color: hasOverride ? const Color(0xFFf59e0b) : const Color(0xFF10b981),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        if (hasOverride) ...[
          Text(
            _screen?['override_expires_at'] != null
                ? 'Manual override active. Resumes automatically at ${_fmtOverrideTime(_screen!['override_expires_at'] as String?)}.'
                : 'Manual override active — schedule paused indefinitely.',
            style: const TextStyle(color: Color(0xFF6b7280), fontSize: 12),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _clearing ? null : _resume,
              icon: _clearing
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.refresh, size: 16),
              label: Text(
                _clearing ? 'Resuming…' : 'Resume Schedule',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF064e3b),
                foregroundColor: const Color(0xFF10b981),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 11),
                elevation: 0,
              ),
            ),
          ),
        ] else ...[
          Text(
            _activeSlide != null
                ? 'Schedule is running automatically. Tap Pause to take manual control.'
                : 'Schedule is running. No slide scheduled right now — push one manually.',
            style: const TextStyle(color: Color(0xFF6b7280), fontSize: 12),
          ),
          if (_activeSlide != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pausing ? null : _pause,
                icon: _pausing
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.pause, size: 16),
                label: Text(
                  _pausing ? 'Pausing…' : 'Pause Schedule',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF451a03),
                  foregroundColor: const Color(0xFFf59e0b),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ],
      ]),
    );
  }

  Widget _buildSlideGrid() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text(
          'Push to Screen',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_slides.length}',
            style: const TextStyle(color: Color(0xFF6b7280), fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      if (_slides.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF0f1219),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: const Center(
            child: Text('No slides in this event', style: TextStyle(color: Color(0xFF6b7280), fontSize: 13)),
          ),
        )
      else
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.82,
          ),
          itemCount: _slides.length,
          itemBuilder: (_, i) {
            final s = _slides[i] as Map<String, dynamic>;
            final isActive = _activeSlide?['id'] == s['id'];
            final isPushing = _pushing == s['id'];
            final isInactive = s['is_active'] != true;
            return GestureDetector(
              onTap: isPushing || _pushing != null ? null : () => _push(s['id'] as int),
              child: Opacity(
                opacity: isInactive ? 0.5 : 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0f1219),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isActive ? const Color(0xFF0ea5e9) : Colors.white10,
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Stack(children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                          child: s['type'] == 'video'
                              ? Container(
                                  color: const Color(0xFF1a1f2e),
                                  child: const Center(
                                    child: Icon(Icons.play_circle_outline, color: Color(0xFF6366f1), size: 28),
                                  ),
                                )
                              : s['image_url'] != null
                                  ? Image.network(
                                      s['image_url'] as String,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1a1f2e)),
                                    )
                                  : Container(color: const Color(0xFF1a1f2e)),
                        ),
                        if (isActive)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF0ea5e9).withValues(alpha: 0.15),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                              ),
                              child: const Center(child: _OnScreenBadge()),
                            ),
                          ),
                        if (isPushing)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          s['title'] as String? ?? 'Untitled',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (s['start_time'] != null)
                          Text(
                            '${_fmtTime(s['start_time'])} – ${_fmtTime(s['end_time'])}',
                            style: const TextStyle(color: Color(0xFF4b5563), fontSize: 10, fontFamily: 'monospace'),
                          ),
                      ]),
                    ),
                  ]),
                ),
              ),
            );
          },
        ),
    ]);
  }

  Widget _buildTimeline() {
    final nowMin = _now.hour * 60 + _now.minute;
    final scheduled = _scheduledSlides;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text(
        "TODAY'S TIMELINE",
        style: TextStyle(color: Color(0xFF6b7280), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2),
      ),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0f1219),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: scheduled.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            final start = _toMin(s['start_time']);
            final end = _toMin(s['end_time']);
            final isNow = start <= nowMin && end > nowMin;
            final isPast = end <= nowMin;
            final isLast = i == scheduled.length - 1;
            return Column(children: [
              Container(
                color: isNow ? const Color(0xFF022c22).withValues(alpha: 0.5) : Colors.transparent,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isNow
                            ? const Color(0xFF10b981)
                            : isPast
                                ? const Color(0xFF374151)
                                : const Color(0xFF38bdf8),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 82,
                      child: Text(
                        '${_fmtTime(s['start_time'])} – ${_fmtTime(s['end_time'])}',
                        style: const TextStyle(color: Color(0xFF4b5563), fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        s['title'] as String? ?? 'Untitled',
                        style: TextStyle(
                          color: isNow
                              ? const Color(0xFF10b981)
                              : isPast
                                  ? const Color(0xFF374151)
                                  : const Color(0xFFd1d5db),
                          fontSize: 12,
                          fontWeight: isNow ? FontWeight.w600 : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isNow)
                      Text(
                        '−${_fmtDiff(end - nowMin)}',
                        style: const TextStyle(color: Color(0xFF059669), fontSize: 11, fontFamily: 'monospace'),
                      )
                    else if (!isPast)
                      Text(
                        'in ${_fmtDiff(start - nowMin)}',
                        style: const TextStyle(color: Color(0xFF0284c7), fontSize: 11, fontFamily: 'monospace'),
                      ),
                  ]),
                ),
              ),
              if (!isLast) const Divider(height: 1, color: Colors.white10, indent: 14),
            ]);
          }).toList(),
        ),
      ),
    ]);
  }
}

class _OnScreenBadge extends StatelessWidget {
  const _OnScreenBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0284c7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.play_arrow, color: Colors.white, size: 12),
        SizedBox(width: 3),
        Text('On Screen', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
