part of 'package:windblog_admin_flutter/main.dart';

String? _validatedMediaImageUrl(AdminApiClient api, String? rawUrl) {
  try {
    final normalized = api.normalizeUrl(rawUrl);
    final uri = Uri.tryParse(normalized);
    final scheme = uri?.scheme.toLowerCase();
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (scheme != 'http' && scheme != 'https')) {
      return null;
    }
    return normalized;
  } catch (_) {
    return null;
  }
}

Widget _mediaImageError(BuildContext context, {required bool invalidUrl}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 6),
          Text(
            t(
              context,
              invalidUrl
                  ? 'media_image_invalid_url'
                  : 'media_image_load_failed',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}

class _FriendlyNetworkImage extends StatelessWidget {
  const _FriendlyNetworkImage({
    required this.url,
    required this.api,
    this.width,
    this.height,
    this.fit,
    this.loadingBuilder,
  });

  final String url;
  final AdminApiClient api;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final ImageLoadingBuilder? loadingBuilder;

  @override
  Widget build(BuildContext context) {
    final validUrl = _validatedMediaImageUrl(api, url);
    if (validUrl == null) {
      return _mediaImageError(context, invalidUrl: true);
    }

    return Image.network(
      validUrl,
      headers: const {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: loadingBuilder,
      errorBuilder: (context, error, stackTrace) =>
          _mediaImageError(context, invalidUrl: false),
    );
  }
}

class _ProgressiveImage extends StatefulWidget {
  const _ProgressiveImage({
    required this.previewUrl,
    required this.thumbnailUrl,
    required this.fallbackUrl,
    required this.width,
    required this.height,
    required this.fit,
    required this.api,
  });

  final AdminApiClient api;

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
    return _validatedMediaImageUrl(widget.api, widget.previewUrl?.trim()) ??
        _validatedMediaImageUrl(widget.api, widget.thumbnailUrl?.trim()) ??
        _validatedMediaImageUrl(widget.api, widget.fallbackUrl) ??
        '';
  }

  Future<void> _upgradeToThumbnail() async {
    final thumb = _validatedMediaImageUrl(
      widget.api,
      widget.thumbnailUrl?.trim(),
    );
    if (thumb == null || thumb == _currentUrl) {
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
    if (_currentUrl.isEmpty) {
      return _mediaImageError(context, invalidUrl: true);
    }

    return _FriendlyNetworkImage(
      url: _currentUrl,
      api: widget.api,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
    );
  }
}
