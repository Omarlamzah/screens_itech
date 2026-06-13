import 'dart:async';
import 'package:flutter/material.dart';
import '../services/sound_service.dart';

enum ToastType { success, error, warning, info }

// ─── AppToast ─────────────────────────────────────────────────────────────────
// Slide-in banner from top of screen (like sonner toasts in the Next.js web app).
// Usage:
//   AppToast.show(context, message: 'Pushed!', type: ToastType.success);
//   AppToast.show(context, message: 'Error', type: ToastType.error, withSound: true);

class AppToast {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
    int seconds = 3,
    bool withSound = false,
  }) {
    _timer?.cancel();
    _entry?.remove();
    _entry = null;

    if (withSound) _playSound(type);

    final overlay = Overlay.of(context);
    late OverlayEntry e;
    e = OverlayEntry(
      builder: (_) => _ToastBanner(
        message: message,
        type: type,
        seconds: seconds,
        onClose: () {
          e.remove();
          if (_entry == e) _entry = null;
        },
      ),
    );
    _entry = e;
    overlay.insert(e);

    _timer = Timer(Duration(seconds: seconds), () {
      if (_entry == e) {
        e.remove();
        _entry = null;
      }
    });
  }

  static void _playSound(ToastType type) {
    final s = SoundService();
    switch (type) {
      case ToastType.success:
        s.playSuccess();
      case ToastType.error:
        s.playError();
      case ToastType.warning:
      case ToastType.info:
        s.playNotification();
    }
  }
}

// ─── AlarmOverlay ─────────────────────────────────────────────────────────────
// Full-screen alarm modal with visible countdown — mirrors the fullscreen
// countdown prompt in the Next.js tv/page.tsx.
// Usage:
//   AlarmOverlay.show(context,
//     title: 'Connection lost',
//     message: 'The display screen could not be reached.',
//     countdown: 30,
//     type: ToastType.warning,
//   );

class AlarmOverlay {
  static void show(
    BuildContext context, {
    required String title,
    String? message,
    int countdown = 30,
    ToastType type = ToastType.warning,
    String? actionLabel,
    VoidCallback? onAction,
    bool withSound = true,
    VoidCallback? onDismiss,
  }) {
    if (withSound) SoundService().playAlarm();
    late OverlayEntry e;
    e = OverlayEntry(
      builder: (_) => _AlarmPanel(
        title: title,
        message: message,
        countdown: countdown,
        type: type,
        actionLabel: actionLabel,
        onAction: onAction,
        onDismiss: () {
          e.remove();
          onDismiss?.call();
        },
      ),
    );
    Overlay.of(context).insert(e);
  }
}

// ─── _ToastBanner ─────────────────────────────────────────────────────────────

class _ToastBanner extends StatefulWidget {
  final String message;
  final ToastType type;
  final int seconds;
  final VoidCallback onClose;
  const _ToastBanner({
    required this.message,
    required this.type,
    required this.seconds,
    required this.onClose,
  });

  @override
  State<_ToastBanner> createState() => _ToastBannerState();
}

class _ToastBannerState extends State<_ToastBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late int _secs;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _secs = widget.seconds;
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _slide = Tween<Offset>(begin: const Offset(0, -1.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secs = (_secs - 1).clamp(0, 9999));
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Color get _bg => switch (widget.type) {
        ToastType.success => const Color(0xFF064e3b),
        ToastType.error => const Color(0xFF7f1d1d),
        ToastType.warning => const Color(0xFF78350f),
        ToastType.info => const Color(0xFF1e3a5f),
      };

  Color get _fg => switch (widget.type) {
        ToastType.success => const Color(0xFF10b981),
        ToastType.error => const Color(0xFFf87171),
        ToastType.warning => const Color(0xFFfbbf24),
        ToastType.info => const Color(0xFF60a5fa),
      };

  IconData get _icon => switch (widget.type) {
        ToastType.success => Icons.check_circle_outline_rounded,
        ToastType.error => Icons.error_outline_rounded,
        ToastType.warning => Icons.warning_amber_rounded,
        ToastType.info => Icons.info_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPad + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: _fg.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(children: [
              Icon(_icon, color: _fg, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.message,
                  style: TextStyle(
                      color: _fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 8),
              // Countdown badge — clearly visible, mirrors the web countdown pill
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: _fg.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: _fg.withValues(alpha: 0.28)),
                ),
                child: Text(
                  '${_secs}s',
                  style: TextStyle(
                    color: _fg,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: widget.onClose,
                child: Icon(Icons.close_rounded,
                    color: _fg.withValues(alpha: 0.6), size: 16),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── _AlarmPanel ─────────────────────────────────────────────────────────────

class _AlarmPanel extends StatefulWidget {
  final String title;
  final String? message;
  final int countdown;
  final ToastType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  const _AlarmPanel({
    required this.title,
    this.message,
    required this.countdown,
    required this.type,
    this.actionLabel,
    this.onAction,
    required this.onDismiss,
  });

  @override
  State<_AlarmPanel> createState() => _AlarmPanelState();
}

class _AlarmPanelState extends State<_AlarmPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade;
  late int _secs;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _secs = widget.countdown;
    _fade = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250))
      ..forward();

    if (_secs > 0) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _secs = (_secs - 1).clamp(0, 9999));
        if (_secs == 0) {
          _ticker?.cancel();
          _dismiss();
        }
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _fade.dispose();
    super.dispose();
  }

  Color get _accent => switch (widget.type) {
        ToastType.success => const Color(0xFF10b981),
        ToastType.error => const Color(0xFFf87171),
        ToastType.warning => const Color(0xFFfbbf24),
        ToastType.info => const Color(0xFF60a5fa),
      };

  IconData get _icon => switch (widget.type) {
        ToastType.success => Icons.check_circle_outline_rounded,
        ToastType.error => Icons.error_outline_rounded,
        ToastType.warning => Icons.notifications_active_rounded,
        ToastType.info => Icons.info_outline_rounded,
      };

  void _dismiss() {
    _ticker?.cancel();
    if (!mounted) {
      widget.onDismiss();
      return;
    }
    _fade.reverse().whenComplete(widget.onDismiss);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: GestureDetector(
        // Tap outside the card to dismiss
        onTap: _dismiss,
        child: Container(
          color: Colors.black.withValues(alpha: 0.78),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // absorb taps inside card
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF0f1219),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: _accent.withValues(alpha: 0.38), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.65),
                        blurRadius: 50),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon ring
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: _accent.withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: Icon(_icon, color: _accent, size: 34),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    Text(
                      widget.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          height: 1.25),
                      textAlign: TextAlign.center,
                    ),

                    // Subtitle/message
                    if (widget.message != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.message!,
                        style: const TextStyle(
                            color: Color(0xFF9ca3af), fontSize: 14, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 26),

                    // Countdown pill — the key "clearly visible" element
                    if (_secs > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 11),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.14)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Auto-dismiss in',
                              style: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 13),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '$_secs',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                height: 1,
                              ),
                            ),
                            Text(
                              's',
                              style: TextStyle(
                                  color: Colors.grey.shade300, fontSize: 16),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 22),

                    // Buttons
                    Row(children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _dismiss,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF9ca3af),
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: const Text('Dismiss'),
                        ),
                      ),
                      if (widget.actionLabel != null) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              widget.onAction?.call();
                              _dismiss();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 13),
                              elevation: 0,
                            ),
                            child: Text(widget.actionLabel!),
                          ),
                        ),
                      ],
                    ]),

                    const SizedBox(height: 10),
                    Text(
                      'Tap outside to dismiss',
                      style: TextStyle(
                          color: Colors.grey.shade700, fontSize: 11),
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
