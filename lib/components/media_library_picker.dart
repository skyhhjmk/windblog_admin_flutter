part of 'package:windblog_admin_flutter/main.dart';

class MediaLibraryPicker extends StatefulWidget {
  const MediaLibraryPicker({
    super.key,
    required this.api,
    this.onSelected,
    this.multiSelect = false,
  });

  final AdminApiClient api;
  final Function(List<MediaItem>)? onSelected;
  final bool multiSelect;

  @override
  State<MediaLibraryPicker> createState() => _MediaLibraryPickerState();
}

class _MediaLibraryPickerState extends State<MediaLibraryPicker> {
  MediaListResult? mediaResult;
  bool loading = true;
  int page = 1;
  final Set<int> selectedIds = {};
  final List<MediaItem> selectedItems = [];

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    setState(() => loading = true);
    try {
      mediaResult = await widget.api.listMedia(page: page, pageSize: 20);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载媒体失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _toggleSelection(MediaItem item) {
    setState(() {
      if (selectedIds.contains(item.id)) {
        selectedIds.remove(item.id);
        selectedItems.removeWhere((i) => i.id == item.id);
      } else {
        if (!widget.multiSelect) {
          selectedIds.clear();
          selectedItems.clear();
        }
        selectedIds.add(item.id);
        selectedItems.add(item);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : _buildGrid(),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Text('第 $page 页 / 共 ${mediaResult?.total ?? 0} 条'),
              const Spacer(),
              IconButton(
                onPressed: page <= 1 ? null : () {
                  setState(() => page--);
                  _loadMedia();
                },
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                onPressed: (mediaResult?.total ?? 0) <= page * 20 ? null : () {
                  setState(() => page++);
                  _loadMedia();
                },
                icon: const Icon(Icons.chevron_right),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: selectedItems.isEmpty ? null : () {
                  widget.onSelected?.call(selectedItems);
                  Navigator.of(context).pop(selectedItems);
                },
                child: Text(widget.multiSelect ? '选择 (${selectedItems.length})' : '确定选择'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGrid() {
    final items = mediaResult?.items ?? [];
    if (items.isEmpty) {
      return const Center(child: Text('未找到媒体文件'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = selectedIds.contains(item.id);
        return InkWell(
          onTap: () => _toggleSelection(item),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
                width: isSelected ? 3 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (item.isImage)
                  _ProgressiveImage(
                    previewUrl: item.previewUrl,
                    thumbnailUrl: item.thumbnailUrl,
                    fallbackUrl: item.url,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  )
                else
                  const Center(child: Icon(Icons.insert_drive_file, size: 40)),
                if (isSelected)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Theme.of(context).primaryColor,
                      child: const Icon(Icons.check, size: 16, color: Colors.white),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    color: Colors.black54,
                    child: Text(
                      item.fileName,
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
