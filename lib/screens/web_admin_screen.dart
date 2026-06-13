import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'setup_screen.dart';

class WebAdminScreen extends StatefulWidget {
  final String url;
  const WebAdminScreen({super.key, required this.url});

  @override
  State<WebAdminScreen> createState() => _WebAdminScreenState();
}

class _WebAdminScreenState extends State<WebAdminScreen> {
  late final WebViewController _ctrl;
  bool _loading = true;
  String _title = 'Admin';

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0a0d12))
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (url) async {
          final t = await _ctrl.getTitle();
          setState(() { _loading = false; _title = t ?? 'Admin'; });
        },
        onWebResourceError: (_) => setState(() => _loading = false),
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  Widget _buildWebView() {
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
      gestureRecognizers: {Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new)},
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () async {
            if (await _ctrl.canGoBack()) {
              await _ctrl.goBack();
            } else {
              if (context.mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SetupScreen()));
              }
            }
          },
        ),
        title: Text(_title, style: const TextStyle(fontSize: 15), overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: () => _ctrl.reload()),
          IconButton(
            icon: const Icon(Icons.home_outlined, size: 20),
            onPressed: () => _ctrl.loadRequest(Uri.parse(widget.url)),
            tooltip: 'Home',
          ),
        ],
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(color: Color(0xFF6366f1), backgroundColor: Colors.transparent),
              )
            : null,
      ),
      body: _buildWebView(),
    );
  }
}
