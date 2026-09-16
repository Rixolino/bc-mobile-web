import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Browser interno all'app con funzioni basiche:
/// navigazione avanti/indietro, reload, apertura nel browser esterno
/// e condivisione della pagina/notizia.
class NewsBrowserScreen extends StatefulWidget {
  final String url;
  final String? title;

  const NewsBrowserScreen({super.key, required this.url, this.title});

  @override
  State<NewsBrowserScreen> createState() => _NewsBrowserScreenState();
}

class _NewsBrowserScreenState extends State<NewsBrowserScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  String _currentUrl = '';
  // Se la pagina corrente e un PDF, qui c'e l'URL reale del file
  // (il WebView mostra invece il viewer embedded).
  String? _pdfUrl;

  /// Rileva gli URL di file PDF (ignorando query string e fragment).
  static bool _isPdfUrl(String url) {
    final path = Uri.tryParse(url)?.path ?? url;
    return path.toLowerCase().endsWith('.pdf');
  }

  /// URL del viewer embedded per mostrare un PDF dentro il WebView.
  static String _pdfViewerUrl(String pdfUrl) =>
      'https://docs.google.com/gview?embedded=1&url=${Uri.encodeComponent(pdfUrl)}';

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
    if (_isPdfUrl(widget.url)) _pdfUrl = widget.url;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _progress = 0);
          },
          // Intercetta i link a PDF e mostrali nel viewer embedded
          // (il WebView Android non renderizza i PDF in modo nativo).
          onNavigationRequest: (request) {
            if (_isPdfUrl(request.url) && !request.url.startsWith('https://docs.google.com/gview')) {
              _openPdf(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageFinished: (url) async {
            final back = await _controller.canGoBack();
            final forward = await _controller.canGoForward();
            if (!mounted) return;
            setState(() {
              // Se stiamo mostrando un PDF, mantieni l'URL reale del file
              // per titolo, condivisione e apertura esterna.
              if (!url.startsWith('https://docs.google.com/gview')) {
                _currentUrl = url;
              }
              _canGoBack = back;
              _canGoForward = forward;
              _progress = 100;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(_pdfUrl != null ? _pdfViewerUrl(widget.url) : widget.url));
  }

  /// Mostra un PDF nel viewer embedded.
  void _openPdf(String pdfUrl) {
    _pdfUrl = pdfUrl;
    _currentUrl = pdfUrl;
    _controller.loadRequest(Uri.parse(_pdfViewerUrl(pdfUrl)));
    _refreshNavState();
  }

  Future<void> _refreshNavState() async {
    final back = await _controller.canGoBack();
    final forward = await _controller.canGoForward();
    if (!mounted) return;
    setState(() {
      _canGoBack = back;
      _canGoForward = forward;
    });
  }

  Future<void> _shareNews() async {
    final title = (widget.title ?? '').trim();
    final text = title.isNotEmpty ? '$title\n$_currentUrl' : _currentUrl;
    await SharePlus.instance.share(ShareParams(text: text, subject: title.isNotEmpty ? title : null));
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(_currentUrl);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[NewsBrowser] Cannot open url $_currentUrl: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_pdfUrl != null)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'PDF',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    (widget.title ?? '').trim().isNotEmpty ? widget.title!.trim() : 'Notizia',
                    style: const TextStyle(fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              _currentUrl,
              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Condividi',
            onPressed: _shareNews,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser_rounded),
            tooltip: 'Apri nel browser',
            onPressed: _openExternal,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Ricarica',
            onPressed: () {
              _controller.reload();
              _refreshNavState();
            },
          ),
        ],
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _progress / 100,
                  minHeight: 3,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Indietro',
              onPressed: _canGoBack
                  ? () async {
                      await _controller.goBack();
                      _refreshNavState();
                    }
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_rounded),
              tooltip: 'Avanti',
              onPressed: _canGoForward
                  ? () async {
                      await _controller.goForward();
                      _refreshNavState();
                    }
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Condividi notizia',
              onPressed: _shareNews,
            ),
            IconButton(
              icon: const Icon(Icons.open_in_browser_rounded),
              tooltip: 'Apri nel browser',
              onPressed: _openExternal,
            ),
          ],
        ),
      ),
    );
  }
}
