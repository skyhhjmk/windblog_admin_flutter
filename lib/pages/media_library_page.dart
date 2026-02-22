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
  bool gridMode = true;
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
          SnackBar(content: Text('\u52a0\u8f7d\u5a92\u4f53\u5217\u8868\u5931\u8d25: $e')),
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
          SnackBar(content: Text('\u52a0\u8f7d\u672a\u5f15\u7528\u5a92\u4f53\u5931\u8d25: $e')),
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
          SnackBar(content: Text('\u91cd\u65b0\u626b\u63cf\u5931\u8d25: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  Future<void> _uploadMedia() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
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
          const SnackBar(content: Text('Upload success')),
        );
      }
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('\u5220\u9664\u5a92\u4f53\u5931\u8d25: $e')),
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
            const TabBar(
              tabs: [
                Tab(text: '\u5a92\u4f53\u5e93'),
                Tab(text: '\u672a\u5f15\u7528\u6587\u4ef6'),
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
            ToggleButtons(
              isSelected: [gridMode, !gridMode],
              onPressed: (index) => setState(() => gridMode = index == 0),
              children: const [
                Icon(Icons.grid_view),
                Icon(Icons.list),
              ],
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _uploadMedia,
                      child: const Text('Close'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: scanning ? null : _scanReferences,
              child: Text(scanning ? 'Scanning...' : 'Rescan'),
            ),
            const Spacer(),
            Text('\u603b\u6570: $total'),
          ],
        ),
        if (scanResult != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              '\u626b\u63cf\u7ed3\u679c\uff1a\u626b\u63cf\u6587\u7ae0 ${scanResult!.postsScanned} \u7bc7\uff0c\u5efa\u7acb\u5f15\u7528 ${scanResult!.referencesCreated} \u6761\uff0c\u672a\u5f15\u7528 ${scanResult!.unreferenced} \u4e2a\u3002',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: loadingMedia
              ? const Center(child: CircularProgressIndicator())
              : gridMode
                  ? _buildGridView()
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
            ? const Center(child: Text('No unreferenced media'))
            : ListView.separated(
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

  Widget _buildGridView() {
    final items = mediaResult?.items ?? [];
    if (items.isEmpty) {
      return const Center(child: Text('No media found'));
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildMediaCard(items[index]),
    );
  }

  Widget _buildListView() {
    final items = mediaResult?.items ?? [];
    if (items.isEmpty) {
      return const Center(child: Text('No media found'));
    }
    return ListView.separated(
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

  Widget _buildMediaCard(MediaItem item) {
    final preview = item.isImage
        ? _ProgressiveImage(
            previewUrl: item.previewUrl,
            thumbnailUrl: item.thumbnailUrl,
            fallbackUrl: item.url,
            width: double.infinity,
            height: 140,
            fit: BoxFit.contain,
          )
        : const SizedBox(
            height: 140,
            child: Center(child: Icon(Icons.insert_drive_file, size: 48)),
          );
    return Card(
      child: InkWell(
        onTap: () => _openMediaDetail(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 140,
              color: Colors.grey.shade100,
              child: preview,
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                item.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${_formatBytes(item.size)} - ${item.uploadedByName ?? 'Unknown'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (item.requiresManualOriginal)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'Original file >5MB, load manually in detail dialog',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Wrap(
                spacing: 4,
                children: item.references
                    .map((ref) => Chip(
                          label: Text(ref.postSlug),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMediaDetail(MediaItem item) async {
    bool loadOriginal = !item.requiresManualOriginal;
    await showDialog<void>(
      context: context,
      builder: (context) =>
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
                        Text('\u7c7b\u578b: ${item.mimeType}'),
                        Text('\u5927\u5c0f: ${_formatBytes(item.size)}'),
                        SelectableText('\u5730\u5740: ${item.url}'),
                        if (item.requiresManualOriginal)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: OutlinedButton(
                              onPressed: loadOriginal
                                  ? null
                                  : () =>
                                  setLocalState(() => loadOriginal = true),
                              child: Text(item.isImage ? 'Load Original Image' : 'Load Original File'),
                            ),
                          ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
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
        Text('\u7b2c $page \u9875 / \u5171 $total \u6761'),
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
                      child: const Text('Close'),
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

