import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:perdev/main.dart';

class MiniProgramViewerPage extends StatefulWidget {
  const MiniProgramViewerPage({super.key});

  @override
  State<MiniProgramViewerPage> createState() => _MiniProgramViewerPageState();
}

class _MiniProgramViewerPageState extends State<MiniProgramViewerPage> {
  late final WebViewController _controller;
  MiniProgram? _miniProgram;
  bool _isLoading = true;
  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is MiniProgram) {
        _miniProgram = args;
        _initializeWebView(args.url);
        ApiService.incrementLaunchCount('wp', args.name);
      }
      _isInit = true;
    }
  }

  void _initializeWebView(String url) {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            });
          },
          onWebResourceError: (WebResourceError error) {
             debugPrint('WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    if (_miniProgram == null) {
      return const Scaffold(body: Center(child: Text("Error: No data")));
    }

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: WebViewWidget(controller: _controller),
          ),

          IgnorePointer(
            ignoring: !_isLoading,
            child: AnimatedOpacity(
              opacity: _isLoading ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              child: Container(
                color: Theme.of(context).colorScheme.surface,
                width: double.infinity,
                height: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Hero(
                      tag: 'mp_icon_${_miniProgram!.id}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: CachedNetworkImage(
                          imageUrl: _miniProgram!.icon,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          cacheManager: LXFCachedNetworkImageManager(),
                          placeholder: (context, url) => Container(color: Colors.grey[200]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _miniProgram!.name,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 48),
                    const CircularProgressIndicator(),
                  ],
                ),
              ),
            ),
          ),
          
          if (!_isLoading)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.5),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
