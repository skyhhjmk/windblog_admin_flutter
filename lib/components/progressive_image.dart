part of 'package:windblog_admin_flutter/main.dart';

class _ProgressiveImage extends StatefulWidget {
  const _ProgressiveImage({
    required this.previewUrl,
    required this.thumbnailUrl,
    required this.fallbackUrl,
    required this.width,
    required this.height,
    required this.fit,
  });

  final String? previewUrl;
  final String? thumbnailUrl;
  final String fallbackUrl;
  final double width;
  final double height;
  final BoxFit fit;

  @override
  State<_ProgressiveImage> createState() => _ProgressiveImageState();
}

class _ProgressiveImageState extends State<_ProgressiveImage> {
  late String _currentUrl;

  @override
  void initState() {
    super.initState();
    _currentUrl = _pickInitialUrl();
    _upgradeToThumbnail();
  }

  @override
  void didUpdateWidget(covariant _ProgressiveImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.previewUrl != widget.previewUrl ||
        oldWidget.thumbnailUrl != widget.thumbnailUrl ||
        oldWidget.fallbackUrl != widget.fallbackUrl) {
      _currentUrl = _pickInitialUrl();
      _upgradeToThumbnail();
    }
  }

  String _pickInitialUrl() {
    final preview = widget.previewUrl?.trim();
    if (preview != null && preview.isNotEmpty) {
      return preview;
    }
    final thumb = widget.thumbnailUrl?.trim();
    if (thumb != null && thumb.isNotEmpty) {
      return thumb;
    }
    return widget.fallbackUrl;
  }

  Future<void> _upgradeToThumbnail() async {
    final thumb = widget.thumbnailUrl?.trim();
    if (thumb == null || thumb.isEmpty || thumb == _currentUrl) {
      return;
    }
    final provider = NetworkImage(thumb);
    try {
      await precacheImage(provider, context);
      if (!mounted) return;
      setState(() => _currentUrl = thumb);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Image.network(
      _currentUrl,
      headers: const {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) =>
          Center(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image),
              const SizedBox(height: 4),
              Text('加载失败: $error',
                  style: const TextStyle(fontSize: 8, color: Colors.grey),
                  textAlign: TextAlign.center),
            ],
          )),
    );
  }
}
