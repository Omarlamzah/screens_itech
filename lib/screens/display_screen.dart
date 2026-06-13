import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../widgets/app_toast.dart';
import 'setup_screen.dart';

class DisplayScreen extends StatefulWidget {
  final String url;
  final String mode;
  final String name;
  const DisplayScreen({super.key, required this.url, required this.mode, required this.name});
  @override
  State<DisplayScreen> createState() => _DisplayScreenState();
}

class _DisplayScreenState extends State<DisplayScreen> {
  late final WebViewController _ctrl;
  bool _loading = true;
  bool _hasError = false;
  int _tapCount = 0;
  DateTime? _lastTap;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    debugPrint('[DISPLAY] loading url=${widget.url}');

    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          debugPrint('[DISPLAY] pageStarted=$url');
          setState(() { _loading = true; _hasError = false; });
        },
        onPageFinished: (url) {
          debugPrint('[DISPLAY] pageFinished=$url');
          setState(() => _loading = false);
        },
        onWebResourceError: (err) {
          debugPrint('[DISPLAY] error=${err.description}');
          if (!mounted) return;
          setState(() { _loading = false; _hasError = true; });
          AlarmOverlay.show(
            context,
            title: 'Display connection failed',
            message: err.description,
            countdown: 30,
            type: ToastType.warning,
            actionLabel: 'Reload',
            onAction: () => _ctrl.reload(),
          );
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onTap() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < const Duration(seconds: 2)) {
      _tapCount++;
    } else {
      _tapCount = 1;
    }
    _lastTap = now;
    if (_tapCount >= 5) {
      _tapCount = 0;
      _showExitMenu();
    }
  }

  Future<void> _goToSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_slug'); // prevent auto-reconnect on next launch
    if (!mounted) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SetupScreen()));
  }

  Future<void> _onBackPressed() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1f2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Leave display?', style: TextStyle(color: Colors.white)),
        content: Text(
          '${widget.mode == 'screen' ? 'Screen' : widget.mode == 'pulpit' ? 'Pulpit' : 'Nameplate'}: ${widget.name}',
          style: const TextStyle(color: Color(0xFF9ca3af)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay', style: TextStyle(color: Color(0xFF6366f1))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Go to setup', style: TextStyle(color: Color(0xFF9ca3af))),
          ),
        ],
      ),
    );
    if (leave == true) _goToSetup();
  }

  void _showExitMenu() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1f2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Options', style: TextStyle(color: Colors.white)),
        content: Text(
          '${widget.mode == 'screen' ? 'Screen' : widget.mode == 'pulpit' ? 'Pulpit' : 'Nameplate'}: ${widget.name}',
          style: const TextStyle(color: Color(0xFF9ca3af)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _ctrl.reload();
              AppToast.show(context, message: 'Reloading…', type: ToastType.info);
            },
            child: const Text('Reload', style: TextStyle(color: Color(0xFF6366f1))),
          ),
          TextButton(
            onPressed: () { Navigator.pop(context); _goToSetup(); },
            child: const Text('Change device', style: TextStyle(color: Color(0xFF9ca3af))),
          ),
        ],
      ),
    );
  }

  Widget _buildWebView() {
    // Use hybrid composition on Android for proper touch event handling
    if (_ctrl.platform is AndroidWebViewController) {
      return WebViewWidget.fromPlatformCreationParams(
        params: AndroidWebViewWidgetCreationParams(
          controller: _ctrl.platform as AndroidWebViewController,
          displayWithHybridComposition: true,
        ),
      );
    }
    return WebViewWidget(
      controller: _ctrl,
      gestureRecognizers: {
        Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) _onBackPressed(); },
      child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildWebView(),
          if (_loading)
            IgnorePointer(
              child: const Center(child: CircularProgressIndicator(color: Color(0xFF6366f1))),
            ),
          Positioned(
            top: 0, right: 0,
            child: GestureDetector(
              onTap: _onTap,
              child: const SizedBox(width: 80, height: 80, child: ColoredBox(color: Colors.transparent)),
            ),
          ),
        ],
      ),
    ));  // Scaffold + PopScope
  }
}
