part of 'package:windblog_admin_flutter/main.dart';

class MediaLibraryPage extends StatefulWidget {
  const MediaLibraryPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<MediaLibraryPage> createState() => _MediaLibraryPageState();
}

class _MediaLibraryPageState extends State<MediaLibraryPage> {
  MediaListResult? mediaResult;
  MediaListResult? unreferencedResult;
  MediaScanResult? scanResult;
  bool loadingMedia = true;
  bool loadingUnreferenced = true;
  bool scanning = false;
  int page = 1;
  int unreferencedPage = 1;

  @override
  void initState() {
    super.initState();
    _loadMedia();
    _loadUnreferenced();
  }

  Future<void> _loadMedia() async {
    setState(() => loadingMedia = true);
    try {
      mediaResult = await widget.api.listMedia(page: page, pageSize: 24);
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'load_media_failed')}$e')),
        );
      }
    } finally {
      if (mounted) setState(() => loadingMedia = false);
    }
  }

  Future<void> _loadUnreferenced() async {
    setState(() => loadingUnreferenced = true);
    try {
      unreferencedResult = await widget.api.listMedia(
        page: unreferencedPage,
        pageSize: 24,
        unreferenced: true,
      );
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'load_unreferenced_failed')}$e')),
        );
      }
    } finally {
      if (mounted) setState(() => loadingUnreferenced = false);
    }
  }

  Future<void> _scanReferences() async {
    setState(() => scanning = true);
    try {
      scanResult = await widget.api.scanMedia();
      await _loadMedia();
      await _loadUnreferenced();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'rescan_failed')}$e')),
        );
      }
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  Future<void> _uploadMedia() async {
    final result = await FilePicker.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    final mimeType = _resolveMimeType(file);
    try {
      await widget.api.uploadMedia(
        fileName: file.name,
        bytes: bytes,
        mimeType: mimeType,
      );
      await _loadMedia();
      if (!mounted) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t(context, 'upload_success'))),
        );
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'delete_failed')}$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            TabBar(
              tabs: [
                Tab(text: t(context, 'media_library')),
                Tab(text: t(context, 'unreferenced_files')),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                children: [
                  _buildMediaTab(),
                  _buildUnreferencedTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaTab() {
    final total = mediaResult?.total ?? 0;
    return Column(
      children: [
        Row(
          children: [
            FilledButton(
              onPressed: _uploadMedia,
              child: Text(t(context, 'upload')),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: scanning ? null : _scanReferences,
              child: Text(scanning ? t(context, 'scanning') : t(context, 'rescan')),
            ),
            const Spacer(),
            Text('${t(context, 'total')}: $total'),
          ],
        ),
        if (scanResult != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              t(context, 'scan_result').replaceAll('%d', scanResult!.postsScanned.toString()).replaceFirst('%d', scanResult!.referencesCreated.toString()).replaceFirst('%d', scanResult!.unreferenced.toString()),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: loadingMedia
              ? const Center(child: CircularProgressIndicator())
              : _buildListView(),
        ),
        const SizedBox(height: 8),
        _buildPagination(),
      ],
    );
  }

  Widget _buildUnreferencedTab() {
    return loadingUnreferenced
        ? const Center(child: CircularProgressIndicator())
        : unreferencedResult == null || unreferencedResult!.items.isEmpty
            ? Center(child: Text(t(context, 'no_unreferenced_media')))
            : ListView.separated(
      physics: const BouncingScrollPhysics(),
                itemCount: unreferencedResult!.items.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = unreferencedResult!.items[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(item.fileName.isEmpty
                          ? '?'
                          : item.fileName[0].toUpperCase()),
                    ),
                    title: Text(item.fileName),
                    subtitle: Text('${_formatBytes(item.size)} - uploaded ${item.createdAt.toLocal()}'),
                  );
                },
              );
  }

  Widget _buildListView() {
    final items = mediaResult?.items ?? [];
    if (items.isEmpty) {
      return Center(child: Text(t(context, 'no_media_found')));
    }
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          onTap: () => _openMediaDetail(item),
          leading: item.isImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: _ProgressiveImage(
                    previewUrl: item.previewUrl,
                    thumbnailUrl: item.thumbnailUrl,
                    fallbackUrl: item.url,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                )
              : const Icon(Icons.insert_drive_file),
          title: Text(item.fileName),
          subtitle: Text('${_formatBytes(item.size)} - refs ${item.references.length}'),
        );
      },
    );
  }

  Future<void> _openMediaDetail(MediaItem item) async {
    bool loadOriginal = !item.requiresManualOriginal;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) =>
          StatefulBuilder(
            builder: (context, setLocalState) =>
                AlertDialog(
                  title: Text(item.fileName),
                  content: SizedBox(
                    width: 640,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.isImage)
                          Container(
                            width: double.infinity,
                            height: 320,
                            color: Colors.black12,
                            child: loadOriginal
                                ? Image.network(
                              item.url,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                              const Center(child: Icon(Icons.broken_image)),
                            )
                                : _ProgressiveImage(
                              previewUrl: item.previewUrl,
                              thumbnailUrl: item.thumbnailUrl,
                              fallbackUrl: item.url,
                              width: double.infinity,
                              height: 320,
                              fit: BoxFit.contain,
                            ),
                          )
                        else
                          const SizedBox(
                            height: 120,
                            child: Center(
                                child: Icon(Icons.insert_drive_file, size: 56)),
                          ),
                        const SizedBox(height: 8),
                        Text('${t(dialogContext, 'type')}: ${item.mimeType}'),
                        Text('${t(dialogContext, 'size')}: ${_formatBytes(item.size)}'),
                        SelectableText('${t(dialogContext, 'url')}: ${item.url}'),
                        if (item.requiresManualOriginal)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: OutlinedButton(
                              onPressed: loadOriginal
                                  ? null
                                  : () =>
                                  setLocalState(() => loadOriginal = true),
                              child: Text(item.isImage ? t(dialogContext, 'load_original_image') : t(dialogContext, 'load_original_file')),
                            ),
                          ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(t(dialogContext, 'close')),
                    ),
                  ],
                ),
          ),
    );
  }
  Widget _buildPagination() {
    final total = mediaResult?.total ?? 0;
    return Row(
      children: [
        Text(t(context, 'page_number').replaceAll('%d', page.toString()).replaceFirst('%d', total.toString())),
        const Spacer(),
        IconButton(
          onPressed: page <= 1
              ? null
              : () {
                  setState(() => page--);
                  _loadMedia();
                },
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          onPressed: page * 24 >= total
              ? null
              : () {
                  setState(() => page++);
                  _loadMedia();
                },
          icon: const Icon(Icons.chevron_right),
        ),
        FilledButton(
          onPressed: _loadMedia,
          child: Text(t(context, 'refresh')),
        ),
      ],
    );
  }

  String _formatBytes(int? bytes) {
    if (bytes == null) return '-';
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}
