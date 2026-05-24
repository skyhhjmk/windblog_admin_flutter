part of 'package:windblog_admin_flutter/main.dart';

class LinksPage extends StatefulWidget {
  const LinksPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<LinksPage> createState() => _LinksPageState();
}

class _LinksPageState extends State<LinksPage> {
  List<AdminLinkItem> links = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  Future<void> _loadLinks() async {
    setState(() => loading = true);
    try {
      links = await widget.api.listLinks();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'load_failed')}$e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _deleteLink(AdminLinkItem link) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text(t(context, 'confirm_delete')),
            content: Text(
                t(context, 'confirm_delete_link').replaceAll('%s', link.name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(t(context, 'cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text(t(context, 'delete')),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      await widget.api.deleteLink(link.id);
      await _loadLinks();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'delete_failed')}$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: TabBar(
                    tabs: [
                      Tab(text: '友情链接'),
                      Tab(text: '文章外链'),
                    ],
                    isScrollable: true,
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: () async {
                    final tabIndex = DefaultTabController
                        .of(context)
                        .index;
                    int defaultLinkType = 0;
                    if (tabIndex == 1) {
                      defaultLinkType = 3;
                    }
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AddLinkPage(
                              api: widget.api,
                              onAuthError: widget.onAuthError,
                              defaultLinkType: defaultLinkType,
                            ),
                      ),
                    );
                    _loadLinks();
                  },
                  icon: const Icon(Icons.add),
                  label: Text(t(context, 'add_link')),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _loadLinks,
                  icon: const Icon(Icons.refresh),
                  label: Text(t(context, 'refresh')),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                children: [
                  _buildLinkList(links.where((l) => l.type != 3).toList()),
                  _buildLinkList(links.where((l) => l.type == 3).toList()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkList(List<AdminLinkItem> filteredLinks) {
    if (filteredLinks.isEmpty) {
      return Center(child: Text(t(context, 'no_links')));
    }
    return Card(
      child: ListView.separated(
        itemCount: filteredLinks.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final link = filteredLinks[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundImage:
              link.icon != null ? NetworkImage(link.icon!) : null,
              child: link.icon == null ? const Icon(Icons.link) : null,
            ),
            title: Text(link.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(link.url, style: const TextStyle(fontSize: 12)),
                if (link.description != null)
                  Text(
                    link.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
              ],
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AddLinkPage(
                        api: widget.api,
                        onAuthError: widget.onAuthError,
                        initialLink: link,
                      ),
                ),
              );
              _loadLinks();
            },
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (link.status == 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text(t(context, 'disabled'),
                          style: const TextStyle(fontSize: 10)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AddLinkPage(
                              api: widget.api,
                              onAuthError: widget.onAuthError,
                              initialLink: link,
                            ),
                      ),
                    );
                    _loadLinks();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteLink(link),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
