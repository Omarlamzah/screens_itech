import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../widgets/app_toast.dart';

class RoomControlScreen extends StatefulWidget {
  final int roomId;
  final String roomName;
  final int eventId;
  const RoomControlScreen({super.key, required this.roomId, required this.roomName, required this.eventId});

  @override
  State<RoomControlScreen> createState() => _RoomControlScreenState();
}

class _RoomControlScreenState extends State<RoomControlScreen> {
  Map<String, dynamic>? _room;
  List<dynamic> _contents = [];
  List<dynamic> _presets  = [];
  bool _loading      = true;
  int? _pushing;
  bool _pushingAll   = false;
  int? _clearing;
  String? _rotatingId;
  int? _activatingPreset;
  int? _clearingBg;
  int? _settingBg;
  int? _settingColor;
  int? _togglingOverride;
  Timer? _pollTimer;

  final _orientations = ['0', '90', '180', '270'];

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _silentRefresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  List<dynamic> get _nameplates => (_room?['nameplates'] as List<dynamic>?) ?? [];

  int get _onlineCount => _nameplates.where((np) {
    final lastSeen = np['last_seen_at'] as String?;
    if (lastSeen == null) return false;
    try {
      return DateTime.now().difference(DateTime.parse(lastSeen)).inSeconds < 35;
    } catch (_) {
      return false;
    }
  }).length;

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getRoom(widget.roomId),
        ApiService.getNameplateContents(widget.eventId),
        ApiService.getPresets(widget.roomId).catchError((_) => <dynamic>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _room     = results[0] as Map<String, dynamic>;
        _contents = results[1] as List<dynamic>;
        _presets  = results[2] as List<dynamic>;
        _loading  = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _silentRefresh() async {
    try {
      final room = await ApiService.getRoom(widget.roomId);
      if (mounted) setState(() => _room = room);
    } catch (_) {}
  }

  bool _isOnline(Map<String, dynamic> np) {
    final lastSeen = np['last_seen_at'] as String?;
    if (lastSeen == null) return false;
    try {
      return DateTime.now().difference(DateTime.parse(lastSeen)).inSeconds < 35;
    } catch (_) {
      return false;
    }
  }

  Future<void> _push(int nameplateId, int contentId) async {
    setState(() => _pushing = nameplateId);
    try {
      await ApiService.pushToNameplate(nameplateId, contentId);
      await _silentRefresh();
      if (!mounted) return;
      AppToast.show(context, message: 'Pushed!', type: ToastType.success, withSound: true);
    } catch (_) {
      if (!mounted) return;
      AppToast.show(context, message: 'Push failed', type: ToastType.error, withSound: true);
    } finally {
      if (mounted) setState(() => _pushing = null);
    }
  }

  Future<void> _pushAll(int contentId) async {
    setState(() => _pushingAll = true);
    try {
      await ApiService.pushToAllInRoom(widget.roomId, contentId);
      await _silentRefresh();
      if (!mounted) return;
      final name = (_contents.firstWhere((c) => c['id'] == contentId, orElse: () => <String, dynamic>{}) as Map<String, dynamic>)['person_name'] as String? ?? 'Content';
      AppToast.show(context, message: '"$name" pushed to all iPads', type: ToastType.success, withSound: true);
    } catch (_) {
      if (!mounted) return;
      AppToast.show(context, message: 'Push all failed', type: ToastType.error, withSound: true);
    } finally {
      if (mounted) setState(() => _pushingAll = false);
    }
  }

  Future<void> _clear(int nameplateId) async {
    setState(() => _clearing = nameplateId);
    try {
      await ApiService.clearNameplate(nameplateId);
      await _silentRefresh();
      if (!mounted) return;
      AppToast.show(context, message: 'Cleared', type: ToastType.info);
    } catch (_) {} finally {
      if (mounted) setState(() => _clearing = null);
    }
  }

  Future<void> _rotate(int nameplateId, String current) async {
    setState(() => _rotatingId = '$nameplateId');
    final idx  = _orientations.indexOf(current);
    final next = _orientations[(idx + 1) % _orientations.length];
    try {
      await ApiService.setNameplateOrientation(nameplateId, next);
      await _silentRefresh();
      if (!mounted) return;
      AppToast.show(context, message: 'Rotated to $next°', type: ToastType.info);
    } catch (_) {
      if (!mounted) return;
      AppToast.show(context, message: 'Rotate failed', type: ToastType.error, withSound: true);
    } finally {
      if (mounted) setState(() => _rotatingId = null);
    }
  }

  Future<void> _activatePreset(int presetId) async {
    setState(() => _activatingPreset = presetId);
    try {
      await ApiService.activatePreset(presetId);
      await _silentRefresh();
      if (!mounted) return;
      AppToast.show(context, message: 'Preset activated!', type: ToastType.success, withSound: true);
    } catch (_) {
      if (!mounted) return;
      AppToast.show(context, message: 'Activation failed', type: ToastType.error, withSound: true);
    } finally {
      if (mounted) setState(() => _activatingPreset = null);
    }
  }

  Future<void> _clearNameplateBg(int nameplateId) async {
    setState(() => _clearingBg = nameplateId);
    try {
      await ApiService.clearNameplateBackground(nameplateId);
      await _silentRefresh();
      if (!mounted) return;
      AppToast.show(context, message: 'Using content background', type: ToastType.info);
    } catch (_) {
      if (!mounted) return;
      AppToast.show(context, message: 'Failed', type: ToastType.error, withSound: true);
    } finally {
      if (mounted) setState(() => _clearingBg = null);
    }
  }

  Future<void> _toggleOverride(int nameplateId, {required bool enable}) async {
    setState(() => _togglingOverride = nameplateId);
    try {
      await ApiService.toggleNameplateOverride(nameplateId, enabled: enable);
      await _silentRefresh();
      if (!mounted) return;
      AppToast.show(
        context,
        message: enable ? 'Using iPad image' : 'Using content image',
        type: ToastType.info,
      );
    } catch (_) {
      if (!mounted) return;
      AppToast.show(context, message: 'Failed', type: ToastType.error, withSound: true);
    } finally {
      if (mounted) setState(() => _togglingOverride = null);
    }
  }

  Future<void> _setNameplateColor(int nameplateId, String color) async {
    setState(() => _settingColor = nameplateId);
    try {
      await ApiService.setNameplateOverrideColor(nameplateId, color);
      await _silentRefresh();
      if (!mounted) return;
      AppToast.show(context, message: 'Showing solid color', type: ToastType.info);
    } catch (_) {
      if (!mounted) return;
      AppToast.show(context, message: 'Failed', type: ToastType.error, withSound: true);
    } finally {
      if (mounted) setState(() => _settingColor = null);
    }
  }

  Future<void> _setNameplateBg(int nameplateId) async {
    final picker = ImagePicker();
    final xfile  = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xfile == null) return;
    setState(() => _settingBg = nameplateId);
    try {
      await ApiService.setNameplateBackground(nameplateId, File(xfile.path));
      await _silentRefresh();
      if (!mounted) return;
      AppToast.show(context, message: 'iPad background updated', type: ToastType.success, withSound: true);
    } catch (_) {
      if (!mounted) return;
      AppToast.show(context, message: 'Upload failed', type: ToastType.error, withSound: true);
    } finally {
      if (mounted) setState(() => _settingBg = null);
    }
  }

  void _showCustomizeDialog(Map<String, dynamic> content) {
    showDialog(
      context: context,
      builder: (_) => _CustomizeDialog(
        content: content,
        onApply: (contentId, fontSize, fontStyle, textColor) async {
          await ApiService.updateNameplateContent(contentId, fontSize: fontSize, fontStyle: fontStyle, textColor: textColor);
          final results = await Future.wait([
            ApiService.getRoom(widget.roomId),
            ApiService.getNameplateContents(widget.eventId),
          ]);
          if (!mounted) return;
          setState(() {
            _room     = results[0] as Map<String, dynamic>;
            _contents = results[1] as List<dynamic>;
          });
          if (!mounted) return;
          AppToast.show(context, message: 'Style updated!', type: ToastType.success, withSound: true);
        },
      ),
    );
  }

  // ── Content picker ───────────────────────────────────────────────────────────

  void _showContentPicker(Map<String, dynamic> np) {
    _openPicker(
      title: 'Push to ${np['name']}',
      onPick: (id) => _push(np['id'] as int, id),
    );
  }

  void _showPushAllPicker() {
    _openPicker(
      title: 'Push to all ${_nameplates.length} iPads',
      icon: Icons.send_rounded,
      onPick: _pushAll,
    );
  }

  void _openPicker({required String title, required void Function(int) onPick, IconData icon = Icons.tablet_android}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0f1219),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, ctrl) => Column(children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Icon(icon, color: const Color(0xFF6366f1), size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
            ]),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('${_contents.length} items', style: const TextStyle(color: Color(0xFF6b7280), fontSize: 12)),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Colors.white10),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              itemCount: _contents.length,
              itemBuilder: (_, i) {
                final c = _contents[i] as Map<String, dynamic>;
                final bgColor  = _parseColor(c['background_color'] as String?) ?? const Color(0xFF1e1b4b);
                final txtColor = _parseColor(c['text_color'] as String?) ?? Colors.white;
                final bgImg    = c['background_image_url'] as String?;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: Container(
                    width: 48,
                    height: 36,
                    decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
                    child: bgImg != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(bgImg, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(Icons.person, color: txtColor, size: 18)),
                          )
                        : Center(child: Icon(Icons.person, color: txtColor, size: 18)),
                  ),
                  title: Text(
                    c['person_name'] as String? ?? 'Unnamed',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  subtitle: c['person_title'] != null
                      ? Text(c['person_title'] as String, style: const TextStyle(color: Color(0xFF9ca3af), fontSize: 12))
                      : null,
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFF4b5563), size: 18),
                  onTap: () { Navigator.pop(context); onPick(c['id'] as int); },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Color? _parseColor(String? s) {
    if (s == null) return null;
    s = s.trim().replaceFirst('#', '');
    if (s.length == 6) {
      final v = int.tryParse(s, radix: 16);
      return v != null ? Color(0xFF000000 | v) : null;
    }
    if (s.length == 8) {
      final v = int.tryParse(s, radix: 16);
      return v != null ? Color(v) : null;
    }
    return null;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final total  = _nameplates.length;
    final online = _onlineCount;

    return Scaffold(
      backgroundColor: const Color(0xFF0a0d12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f1219),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.roomName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          if (!_loading && total > 0)
            Text(
              '$online / $total online',
              style: TextStyle(
                fontSize: 11,
                color: online > 0 ? const Color(0xFF10b981) : const Color(0xFF6b7280),
                fontWeight: FontWeight.w500,
              ),
            ),
        ]),
        actions: [
          if (!_loading && _contents.isNotEmpty)
            Tooltip(
              message: 'Push to all iPads',
              child: IconButton(
                icon: _pushingAll
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366f1)))
                    : const Icon(Icons.send_rounded, size: 20),
                onPressed: _pushingAll ? null : _showPushAllPicker,
              ),
            ),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366f1)))
          : _nameplates.isEmpty
              ? const Center(child: Text('No iPads in this room', style: TextStyle(color: Color(0xFF6b7280))))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: const Color(0xFF6366f1),
                  child: ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      // Presets section
                      if (_presets.isNotEmpty) ...[
                        _buildPresetsSection(),
                        const SizedBox(height: 16),
                      ],
                      // iPad cards
                      ..._nameplates.map((np) => _buildIpadCard(np as Map<String, dynamic>)),
                    ],
                  ),
                ),
    );
  }

  // ── Presets section ──────────────────────────────────────────────────────────

  Widget _buildPresetsSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Text('PRESETS', style: TextStyle(color: Color(0xFF6b7280), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
      ),
      SizedBox(
        height: 52,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _presets.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final p = _presets[i] as Map<String, dynamic>;
            final isActivating = _activatingPreset == p['id'];
            return ElevatedButton(
              onPressed: isActivating ? null : () => _activatePreset(p['id'] as int),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1e1b4b),
                foregroundColor: const Color(0xFF818cf8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                elevation: 0,
              ),
              child: isActivating
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF818cf8)))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.play_arrow_rounded, size: 15),
                      const SizedBox(width: 5),
                      Text(p['name'] as String? ?? 'Preset', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
            );
          },
        ),
      ),
    ]);
  }

  // ── iPad card ────────────────────────────────────────────────────────────────

  Widget _buildIpadCard(Map<String, dynamic> np) {
    final online        = _isOnline(np);
    final orientation   = np['orientation'] as String? ?? '0';
    final current       = np['current_content'] as Map<String, dynamic>?;
    final isPushing     = _pushing == np['id'];
    final isClearing    = _clearing == np['id'];
    final isRotating    = _rotatingId == '${np['id']}';
    final bgOverrideImg    = np['bg_override_image_url'] as String?;   // null when disabled
    final bgOverrideClr    = np['bg_override_color']     as String?;
    final hasStoredOverride = np['has_stored_override']  as bool? ?? false;
    final overrideEnabled  = np['bg_override_enabled']   as bool? ?? true;
    final hasImgOverride   = bgOverrideImg != null;                    // enabled + has image
    final hasClrOverride   = bgOverrideClr != null && !hasImgOverride;
    final hasOverride      = hasImgOverride || hasClrOverride;
    final canToggle        = hasStoredOverride;                        // stored image exists (even if disabled)
    final isClearingBg     = _clearingBg      == np['id'];
    final isSettingColor   = _settingColor    == np['id'];
    final isTogglingOv     = _togglingOverride == np['id'];
    final contentBgColor   = (current?['background_color'] as String?) ?? '#1a1a2e';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0f1219),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: online
              ? const Color(0xFF10b981).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header ──────────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: online ? const Color(0xFF10b981) : const Color(0xFF4b5563),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                np['name'] as String? ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            if (orientation != '0') ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFF082f49), borderRadius: BorderRadius.circular(20)),
                child: Text('${orientation}°', style: const TextStyle(color: Color(0xFF38bdf8), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 6),
            ],
            if (online)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFF064e3b), borderRadius: BorderRadius.circular(20)),
                child: const Text('LIVE', style: TextStyle(color: Color(0xFF10b981), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
          ]),
        ),

        const SizedBox(height: 10),

        // ── Nameplate visual preview ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _NameplatePreview(np: np, content: current, isOnline: online),
        ),

        // ── Background source toggle ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Row(children: [
            const Text('Fond :', style: TextStyle(color: Color(0xFF6b7280), fontSize: 11, fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),

            if (canToggle) ...[
              // ── Both images exist: show simple 2-chip toggle ───────────────
              _BgSourceChip(
                label: 'Contenu',
                icon: Icons.image_outlined,
                active: !overrideEnabled,
                loading: isTogglingOv && overrideEnabled,
                onTap: (isTogglingOv || !overrideEnabled) ? null
                    : () => _toggleOverride(np['id'] as int, enable: false),
              ),
              const SizedBox(width: 6),
              _BgSourceChip(
                label: 'iPad',
                icon: Icons.tablet_android_rounded,
                active: overrideEnabled,
                loading: isTogglingOv && !overrideEnabled,
                onTap: (isTogglingOv || overrideEnabled) ? null
                    : () => _toggleOverride(np['id'] as int, enable: true),
                onClear: isClearingBg ? null : () => _clearNameplateBg(np['id'] as int),
              ),
            ] else ...[
              // ── No stored override: show Contenu + upload button ────────────
              _BgSourceChip(
                label: 'Contenu',
                icon: Icons.image_outlined,
                active: !hasOverride,
                loading: isClearingBg,
                onTap: hasOverride ? (isClearingBg ? null : () => _clearNameplateBg(np['id'] as int)) : null,
              ),
              const SizedBox(width: 6),
              _BgSourceChip(
                label: 'Couleur',
                icon: Icons.circle,
                iconColor: _parseColor(contentBgColor) ?? const Color(0xFF1a1a2e),
                active: hasClrOverride,
                loading: isSettingColor,
                onTap: isSettingColor ? null : () => _setNameplateColor(np['id'] as int, contentBgColor),
                onClear: hasClrOverride ? (isClearingBg ? null : () => _clearNameplateBg(np['id'] as int)) : null,
              ),
              const SizedBox(width: 6),
              _BgSourceChip(
                label: '+ iPad',
                icon: Icons.add_photo_alternate_outlined,
                active: false,
                loading: _settingBg == np['id'],
                onTap: (_settingBg == np['id']) ? null : () => _setNameplateBg(np['id'] as int),
              ),
            ],
          ]),
        ),

        const SizedBox(height: 12),

        // ── Action buttons ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Row(children: [
            // Push
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                onPressed: isPushing ? null : () => _showContentPicker(np),
                icon: isPushing
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.bolt_rounded, size: 16),
                label: Text(isPushing ? 'Pushing…' : 'Push', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
            // Rotate
            _OutlineIconBtn(
              onPressed: isRotating ? null : () => _rotate(np['id'] as int, orientation),
              loading: isRotating,
              color: orientation != '0' ? const Color(0xFF38bdf8) : const Color(0xFF6b7280),
              borderColor: orientation != '0' ? const Color(0xFF0284c7) : Colors.white12,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.rotate_right_rounded, size: 14),
                const SizedBox(width: 3),
                Text('${orientation}°', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(width: 8),
            // Clear
            _OutlineIconBtn(
              onPressed: (isClearing || current == null) ? null : () => _clear(np['id'] as int),
              loading: isClearing,
              color: const Color(0xFFf87171),
              borderColor: const Color(0xFF7f1d1d),
              child: const Icon(Icons.close_rounded, size: 16),
            ),
            const SizedBox(width: 8),
            // Customize
            _OutlineIconBtn(
              onPressed: current == null ? null : () => _showCustomizeDialog(current),
              color: current != null ? const Color(0xFFa78bfa) : const Color(0xFF4b5563),
              borderColor: current != null ? const Color(0xFF4c1d95) : Colors.white12,
              child: const Icon(Icons.tune_rounded, size: 16),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Nameplate preview widget ─────────────────────────────────────────────────

class _NameplatePreview extends StatelessWidget {
  final Map<String, dynamic> np;
  final Map<String, dynamic>? content;
  final bool isOnline;

  const _NameplatePreview({required this.np, required this.content, required this.isOnline});

  Color? _parseColor(String? s) {
    if (s == null) return null;
    s = s.trim().replaceFirst('#', '');
    if (s.length == 6) {
      final v = int.tryParse(s, radix: 16);
      return v != null ? Color(0xFF000000 | v) : null;
    }
    if (s.length == 8) {
      final v = int.tryParse(s, radix: 16);
      return v != null ? Color(v) : null;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bgOverrideColor = _parseColor(np['bg_override_color'] as String?);
    final bgOverrideImg   = np['bg_override_image_url'] as String?;
    final contentBgColor  = _parseColor(content?['background_color'] as String?);
    final contentBgImg    = content?['background_image_url'] as String?;
    final textColor       = _parseColor(content?['text_color'] as String?) ?? Colors.white;

    final bgColor  = bgOverrideColor ?? contentBgColor ?? const Color(0xFF0d1117);
    final bgImgUrl = bgOverrideImg ?? contentBgImg;

    final personName  = content?['person_name'] as String?;
    final personTitle = content?['person_title'] as String?;
    final roleLabel   = content?['role_label'] as String?;
    final groupName   = content?['group_name'] as String?;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 6,
        child: Stack(fit: StackFit.expand, children: [
          // Base background color
          Container(color: bgColor),

          // Background image
          if (bgImgUrl != null)
            Image.network(
              bgImgUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),

          // Dark overlay when image present (readability)
          if (bgImgUrl != null)
            Container(color: Colors.black.withValues(alpha: 0.3)),

          // Content
          if (content != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (roleLabel != null || groupName != null)
                    Text(
                      [roleLabel, groupName].where((s) => s != null).join(' · '),
                      style: TextStyle(color: textColor.withValues(alpha: 0.55), fontSize: 10, letterSpacing: 0.8, fontWeight: FontWeight.w500),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    personName ?? '',
                    style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold, height: 1.15),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  if (personTitle != null)
                    Text(
                      personTitle,
                      style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            )
          else
            Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.tablet_android_rounded, color: Colors.white.withValues(alpha: 0.12), size: 26),
                const SizedBox(height: 4),
                Text('Empty', style: TextStyle(color: Colors.white.withValues(alpha: 0.18), fontSize: 11)),
              ]),
            ),

          // Offline overlay
          if (!isOnline)
            Container(
              color: Colors.black.withValues(alpha: 0.55),
              child: const Center(
                child: Text(
                  'OFFLINE',
                  style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

// ── Customize dialog ─────────────────────────────────────────────────────────

class _CustomizeDialog extends StatefulWidget {
  final Map<String, dynamic> content;
  final Future<void> Function(int id, int fontSize, String fontStyle, String textColor) onApply;

  const _CustomizeDialog({required this.content, required this.onApply});

  @override
  State<_CustomizeDialog> createState() => _CustomizeDialogState();
}

class _CustomizeDialogState extends State<_CustomizeDialog> {
  late int    _fontSize;
  late String _fontStyle;
  late String _textColor;
  final _hexCtrl    = TextEditingController();
  File?  _pickedImage;
  bool   _removeBackground = false;
  bool   _saving = false;
  bool   _uploadingImage = false;

  static const _presetSizes  = [18, 32, 56, 80, 120, 200];
  static const _presetColors = [
    '#ffffff', '#000000', '#ef4444', '#f97316', '#eab308',
    '#22c55e', '#3b82f6', '#8b5cf6', '#ec4899', '#6b7280',
  ];

  @override
  void initState() {
    super.initState();
    _fontSize  = (widget.content['font_size']  as int?)    ?? 80;
    _fontStyle = (widget.content['font_style'] as String?) ?? 'normal';
    _textColor = (widget.content['text_color'] as String?) ?? '#ffffff';
    _hexCtrl.text = _textColor;
  }

  @override
  void dispose() { _hexCtrl.dispose(); super.dispose(); }

  static Color? _hex(String s) {
    s = s.trim().replaceFirst('#', '');
    if (s.length == 6) {
      final v = int.tryParse(s, radix: 16);
      return v != null ? Color(0xFF000000 | v) : null;
    }
    return null;
  }

  FontWeight get _weight => _fontStyle.contains('bold')   ? FontWeight.bold   : FontWeight.normal;
  FontStyle  get _slant  => _fontStyle.contains('italic') ? FontStyle.italic  : FontStyle.normal;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile  = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xfile == null) return;
    setState(() { _pickedImage = File(xfile.path); _removeBackground = false; });
  }

  Future<void> _applyImage() async {
    setState(() => _uploadingImage = true);
    try {
      await ApiService.updateNameplateContentImage(
        widget.content['id'] as int,
        backgroundImage: _removeBackground ? null : _pickedImage,
        removeBackground: _removeBackground,
      );
      await widget.onApply(
        widget.content['id'] as int,
        _fontSize,
        _fontStyle,
        _textColor,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _apply() async {
    if (_pickedImage != null || _removeBackground) {
      await _applyImage();
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onApply(
        widget.content['id'] as int,
        _fontSize,
        _fontStyle,
        _textColor,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _pickPresetColor() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1f2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: const Text('Couleur', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        content: Wrap(
          spacing: 8, runSpacing: 8,
          children: _presetColors.map((c) {
            final col = _hex(c) ?? Colors.white;
            return GestureDetector(
              onTap: () {
                setState(() { _textColor = c; _hexCtrl.text = c; });
                Navigator.pop(ctx);
              },
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: col,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white24),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final personName  = widget.content['person_name'] as String? ?? '';
    final previewColor = _hex(_textColor) ?? Colors.white;
    final swatchColor  = previewColor;
    final previewSize  = (_fontSize > 64 ? 64 : _fontSize).toDouble();

    return Dialog(
      backgroundColor: const Color(0xFF0f1219),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Title ──────────────────────────────────────────────────────
            Row(children: [
              const Icon(Icons.tune_rounded, color: Color(0xFF6366f1), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Personnaliser — $personName',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: Color(0xFF6b7280), size: 18),
              ),
            ]),

            const SizedBox(height: 20),

            // ── Font size ──────────────────────────────────────────────────
            Row(children: [
              const Text('Taille du texte', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFF6366f1), borderRadius: BorderRadius.circular(6)),
                child: Text('${_fontSize}px', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: _presetSizes.map((s) {
                final active = _fontSize == s;
                return GestureDetector(
                  onTap: () => setState(() => _fontSize = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFF6366f1) : const Color(0xFF1a1f2e),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: active ? const Color(0xFF6366f1) : Colors.white12),
                    ),
                    child: Text(
                      '$s',
                      style: TextStyle(
                        color: active ? Colors.white : const Color(0xFF818cf8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF6366f1),
                inactiveTrackColor: Colors.white12,
                thumbColor: const Color(0xFF6366f1),
                overlayColor: const Color(0x336366f1),
              ),
              child: Slider(
                value: _fontSize.toDouble(),
                min: 8,
                max: 200,
                divisions: 192,
                onChanged: (v) => setState(() => _fontSize = v.round()),
              ),
            ),

            const SizedBox(height: 4),

            // ── Style ──────────────────────────────────────────────────────
            const Text('Style', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            Row(children: [
              _styleChip('Normal',   'normal'),
              const SizedBox(width: 6),
              _styleChip('Gras',     'bold'),
              const SizedBox(width: 6),
              _styleChip('Italique', 'italic'),
              const SizedBox(width: 6),
              _styleChip('Gras+I',   'bold italic'),
            ]),

            const SizedBox(height: 16),

            // ── Text color ─────────────────────────────────────────────────
            const Text('Couleur du texte', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            Row(children: [
              GestureDetector(
                onTap: _pickPresetColor,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: swatchColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _hexCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '#ffffff',
                    hintStyle: const TextStyle(color: Color(0xFF4b5563)),
                    filled: true,
                    fillColor: const Color(0xFF1a1f2e),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF6366f1)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (val) {
                    final v = val.trim().startsWith('#') ? val.trim() : '#${val.trim()}';
                    if (_hex(v) != null) setState(() => _textColor = v);
                  },
                ),
              ),
            ]),

            const SizedBox(height: 16),

            // ── Background image ───────────────────────────────────────────
            const Text('Image de fond', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            _buildBgImageSection(widget.content['background_image_url'] as String?),

            const SizedBox(height: 16),

            // ── Preview ────────────────────────────────────────────────────
            const Text('Aperçu', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xFF1a1f2e),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  personName.isEmpty ? 'Aperçu' : personName,
                  style: TextStyle(
                    color: previewColor,
                    fontSize: previewSize,
                    fontWeight: _weight,
                    fontStyle: _slant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Actions ────────────────────────────────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Annuler', style: TextStyle(color: Color(0xFF6b7280))),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: (_saving || _uploadingImage) ? null : _apply,
                icon: (_saving || _uploadingImage)
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 16),
                label: const Text('Appliquer', style: TextStyle(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366f1),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF1e1b4b),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildBgImageSection(String? currentUrl) {
    final hasExisting = currentUrl != null && !_removeBackground;
    final hasPicked   = _pickedImage != null && !_removeBackground;

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Thumbnail preview
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 72, height: 52,
          color: const Color(0xFF1a1f2e),
          child: hasPicked
              ? Image.file(_pickedImage!, fit: BoxFit.cover)
              : (hasExisting
                  ? Image.network(currentUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white24, size: 20))
                  : const Icon(Icons.image_outlined, color: Colors.white24, size: 22)),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (hasPicked)
            Text(
              _pickedImage!.path.split('/').last,
              style: const TextStyle(color: Color(0xFF9ca3af), fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          else if (hasExisting)
            const Text('Image actuelle', style: TextStyle(color: Color(0xFF9ca3af), fontSize: 11)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo_library_outlined, size: 14),
                label: Text(hasPicked || hasExisting ? 'Changer' : 'Choisir', style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF818cf8),
                  side: const BorderSide(color: Colors.white12),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            if (hasPicked || hasExisting) ...[
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: () => setState(() {
                  _pickedImage = null;
                  _removeBackground = currentUrl != null;
                }),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFf87171),
                  side: const BorderSide(color: Color(0xFF7f1d1d)),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Icon(Icons.delete_outline_rounded, size: 16),
              ),
            ],
          ]),
        ]),
      ),
    ]);
  }

  Widget _styleChip(String label, String style) {
    final active   = _fontStyle == style;
    final isBold   = style.contains('bold');
    final isItalic = style.contains('italic');
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _fontStyle = style),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF6366f1) : const Color(0xFF1a1f2e),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? const Color(0xFF6366f1) : Colors.white12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : const Color(0xFF9ca3af),
              fontSize: 11,
              fontWeight: isBold   ? FontWeight.bold   : FontWeight.normal,
              fontStyle:  isItalic ? FontStyle.italic  : FontStyle.normal,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Background source chip ───────────────────────────────────────────────────

class _BgSourceChip extends StatelessWidget {
  final String        label;
  final IconData      icon;
  final Color?        iconColor;
  final bool          active;
  final bool          loading;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  const _BgSourceChip({
    required this.label,
    required this.icon,
    required this.active,
    this.iconColor,
    this.loading = false,
    this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final fg = active ? Colors.white            : const Color(0xFF6b7280);
    final bg = active ? const Color(0xFF1e1b4b) : Colors.transparent;
    final bd = active ? const Color(0xFF6366f1) : Colors.white12;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.fromLTRB(9, 5, onClear != null ? 4 : 9, 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: bd),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          loading
              ? SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 1.8, color: fg))
              : Icon(icon, size: 12, color: iconColor ?? fg),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
          if (onClear != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close_rounded, size: 13, color: fg.withValues(alpha: 0.7)),
            ),
          ],
        ]),
      ),
    );
  }
}

// ── Shared outlined icon button ──────────────────────────────────────────────

class _OutlineIconBtn extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;
  final Color color;
  final Color borderColor;
  final Widget child;

  const _OutlineIconBtn({
    required this.onPressed,
    required this.color,
    required this.borderColor,
    required this.child,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: borderColor.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      ),
      child: loading
          ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: color))
          : child,
    );
  }
}
