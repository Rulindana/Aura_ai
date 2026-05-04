import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class InAppBrowserPage extends StatefulWidget {
  final String title;
  final String initialUrl;

  const InAppBrowserPage({
    super.key,
    required this.title,
    required this.initialUrl,
  });

  @override
  State<InAppBrowserPage> createState() => _InAppBrowserPageState();
}

class _InAppBrowserPageState extends State<InAppBrowserPage> {
  WebViewController? _controller;
  int _loadingProgress = 0;

  @override
  void initState() {
    super.initState();

    if (_supportsInAppWebView()) {
      final raw = widget.initialUrl.trim();
      final safeUrl = raw.startsWith('http://') || raw.startsWith('https://')
          ? raw
          : 'https://www.w3schools.com/';
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (progress) {
              if (!mounted) return;
              setState(() => _loadingProgress = progress);
            },
          ),
        )
        ..loadRequest(Uri.parse(safeUrl));
    }
  }

  bool _supportsInAppWebView() {
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  Future<void> _openExternal() async {
    final uri = Uri.parse(widget.initialUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _controller?.reload(),
            icon: const Icon(Icons.refresh),
          ),
          if (!_supportsInAppWebView())
            IconButton(
              tooltip: 'Open in system browser',
              onPressed: _openExternal,
              icon: const Icon(Icons.open_in_browser),
            ),
        ],
        bottom: _loadingProgress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _loadingProgress / 100),
              )
            : null,
      ),
      body: _supportsInAppWebView()
          ? WebViewWidget(controller: _controller!)
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "In-app browser isn't supported on this platform.",
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Text(widget.initialUrl),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _openExternal,
                    child: const Text("Open in browser"),
                  ),
                ],
              ),
            ),
    );
  }
}
