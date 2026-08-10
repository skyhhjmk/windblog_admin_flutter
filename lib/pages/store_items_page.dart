part of 'package:windblog_admin_flutter/main.dart';

class StoreItemsPage extends StatefulWidget {
  const StoreItemsPage({
    super.key,
    required this.api,
    required this.onAuthError,
  });

  final AdminApiClient api;
  final VoidCallback onAuthError;

  @override
  State<StoreItemsPage> createState() => _StoreItemsPageState();
}

class _StoreItemsPageState extends State<StoreItemsPage> {
  List<StoreItem> items = [];
  bool loading = false;
  int currentPage = 1;
  int totalItems = 0;
  final int pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => loading = true);
    try {
      final result = await widget.api.getStoreItems(
          page: currentPage, pageSize: pageSize);
      items = result.items;
      totalItems = result.total;
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (mounted) {
        AdminFeedback.showSnackBar(context,
          SnackBar(content: Text('${t(context, 'load_failed')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _createItem() async {
    final result = await showDialog<StoreItemRequest>(
      context: context,
      builder: (context) => const _StoreItemEditDialog(),
    );
    if (result == null) return;

    try {
      await widget.api.createStoreItem(result);
      await _loadItems();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      AdminFeedback.showSnackBar(context,
        SnackBar(content: Text('${t(context, 'save_failed')}: $e')),
      );
    }
  }

  Future<void> _editItem(StoreItem item) async {
    final result = await showDialog<StoreItemRequest>(
      context: context,
      builder: (context) => _StoreItemEditDialog(item: item),
    );
    if (result == null) return;

    try {
      await widget.api.updateStoreItem(item.id, result);
      await _loadItems();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      AdminFeedback.showSnackBar(context,
        SnackBar(content: Text('保存失败: $e')),
      );
    }
  }

  Future<void> _deleteItem(StoreItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: Text(t(context, 'confirm_delete')),
            content: Text(
                '${t(context, 'confirm_delete_item_prefix')} "${item.name}" ${t(
                    context, 'confirm_delete_item_suffix')}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(t(context, 'cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: Text(t(context, 'delete')),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    try {
      await widget.api.deleteStoreItem(item.id);
      await _loadItems();
    } on UnauthorizedException {
      widget.onAuthError();
    } catch (e) {
      if (!mounted) return;
      AdminFeedback.showSnackBar(context,
        SnackBar(content: Text('${t(context, 'delete_failed')}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              FilledButton.icon(
                onPressed: _createItem,
                icon: const Icon(Icons.add),
                label: Text(t(context, 'add_item')),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _loadItems,
                icon: const Icon(Icons.refresh),
                label: Text(t(context, 'refresh')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                ? Center(child: Text(t(context, 'no_items')))
                : Card(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final color = item.rarity != null &&
                      item.rarity!.startsWith('#')
                      ? Color(int.parse(item.rarity!.substring(1), radix: 16) +
                      0xFF000000)
                      : Colors.grey;

                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color.withAlpha(51), // ~0.2 * 255
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: color.withAlpha(128)), // ~0.5 * 255
                      ),
                      child: Center(
                        child: Icon(Icons.inventory_2, color: color, size: 20),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(item.name, style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: item.status == 1
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            item.status == 1 ? t(context, 'on_sale') : t(
                                context, 'off_sale'),
                            style: TextStyle(
                              color: item.status == 1
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${item.price} ${t(context, 'points')}',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                        item.description ?? t(context, 'no_description')),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => _editItem(item),
                          child: Text(t(context, 'edit')),
                        ),
                        TextButton(
                          onPressed: () => _deleteItem(item),
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.red),
                          child: Text(t(context, 'delete')),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          if (totalItems > pageSize)
            PaginationBar(
              currentPage: currentPage,
              totalPages: (totalItems / pageSize).ceil().clamp(1, 999999),
              totalItems: totalItems,
              onPageChanged: (newPage) {
                setState(() => currentPage = newPage);
                _loadItems();
              },
            ),
        ],
      ),
    );
  }
}

class _StoreItemEditDialog extends StatefulWidget {
  const _StoreItemEditDialog({this.item});

  final StoreItem? item;

  @override
  State<_StoreItemEditDialog> createState() => _StoreItemEditDialogState();
}

class _StoreItemEditDialogState extends State<_StoreItemEditDialog> {
  late final TextEditingController nameCtrl;
  late final TextEditingController descCtrl;
  late final TextEditingController priceCtrl;
  late final TextEditingController rarityCtrl;
  late final TextEditingController typeCtrl;

  // 扩展信息字段
  late final TextEditingController downloadUrlCtrl;
  late final TextEditingController extractCodeCtrl;
  late final TextEditingController cdkCtrl;
  late final TextEditingController noticeCtrl;

  int status = 1;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    nameCtrl = TextEditingController(text: item?.name ?? '');
    descCtrl = TextEditingController(text: item?.description ?? '');
    priceCtrl = TextEditingController(text: item?.price.toString() ?? '100');
    rarityCtrl = TextEditingController(text: item?.rarity ?? '#4b5563');
    typeCtrl = TextEditingController(text: item?.type ?? 'item');

    // 初始化扩展信息字段
    Map<String, dynamic> extra = {};
    if (item?.extraInfo != null) {
      if (item!.extraInfo is Map) {
        extra = Map<String, dynamic>.from(item.extraInfo);
      } else if (item.extraInfo is String) {
        try {
          extra = jsonDecode(item.extraInfo);
        } catch (_) {}
      }
    }

    downloadUrlCtrl =
        TextEditingController(text: extra['download_url']?.toString() ?? '');
    extractCodeCtrl =
        TextEditingController(text: extra['extract_code']?.toString() ?? '');
    cdkCtrl = TextEditingController(text: extra['cdk']?.toString() ?? '');
    noticeCtrl = TextEditingController(text: extra['notice']?.toString() ?? '');

    if (item != null) {
      status = item.status;
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    descCtrl.dispose();
    priceCtrl.dispose();
    rarityCtrl.dispose();
    typeCtrl.dispose();
    downloadUrlCtrl.dispose();
    extractCodeCtrl.dispose();
    cdkCtrl.dispose();
    noticeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;

    return AlertDialog(
      title: Text(isEdit ? t(context, 'edit_item') : t(context, 'add_item')),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t(context, 'basic_info'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                    labelText: '${t(context, 'item_name')} *',
                    hintText: t(context, 'item_name_hint')),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(
                    labelText: t(context, 'item_description'),
                    hintText: t(context, 'item_description_hint')),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: priceCtrl,
                      decoration: InputDecoration(
                          labelText: '${t(context, 'item_price')} (${t(
                              context, 'points')}) *'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: rarityCtrl,
                      decoration: InputDecoration(
                          labelText: t(context, 'rarity_color')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: typeCtrl,
                      decoration: InputDecoration(
                          labelText: t(context, 'item_type')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: status,
                      decoration: InputDecoration(
                          labelText: t(context, 'status')),
                      items: [
                        DropdownMenuItem(value: 1, child: Text(t(
                            context, 'on_sale'))),
                        DropdownMenuItem(value: 0, child: Text(t(
                            context, 'off_sale'))),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => status = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(t(context, 'extra_functions'), style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue)),
              const Divider(color: Colors.blue),
              TextField(
                controller: downloadUrlCtrl,
                decoration: InputDecoration(
                  labelText: '${t(context, 'download_url')} (download_url)',
                  prefixIcon: const Icon(Icons.link, size: 20),
                  hintText: t(context, 'download_url_hint'),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: extractCodeCtrl,
                decoration: InputDecoration(
                  labelText: '${t(context, 'extract_code')} (extract_code)',
                  prefixIcon: const Icon(Icons.vpn_key_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: cdkCtrl,
                decoration: InputDecoration(
                  labelText: '${t(context, 'cdk')} (cdk)',
                  prefixIcon: const Icon(Icons.password, size: 20),
                  hintText: t(context, 'cdk_hint'),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noticeCtrl,
                decoration: InputDecoration(
                  labelText: '${t(context, 'notice')} (notice)',
                  prefixIcon: const Icon(Icons.info_outline, size: 20),
                  hintText: t(context, 'notice_hint'),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t(context, 'cancel')),
        ),
        FilledButton(
          onPressed: () {
            final name = nameCtrl.text.trim();
            final priceStr = priceCtrl.text.trim();
            final price = int.tryParse(priceStr) ?? -1;

            if (name.isEmpty) {
              AdminFeedback.showSnackBar(context,
                  SnackBar(content: Text(t(context, 'item_name_required'))));
              return;
            }
            if (price < 0) {
              AdminFeedback.showSnackBar(context,
                  SnackBar(content: Text(t(context, 'price_invalid'))));
              return;
            }

            // 构造扩展信息 Map
            final Map<String, dynamic> extraInfo = {};
            if (downloadUrlCtrl.text
                .trim()
                .isNotEmpty) {
              extraInfo['download_url'] = downloadUrlCtrl.text.trim();
            }
            if (extractCodeCtrl.text
                .trim()
                .isNotEmpty) {
              extraInfo['extract_code'] = extractCodeCtrl.text.trim();
            }
            if (cdkCtrl.text
                .trim()
                .isNotEmpty) {
              extraInfo['cdk'] = cdkCtrl.text.trim();
            }
            if (noticeCtrl.text
                .trim()
                .isNotEmpty) {
              extraInfo['notice'] = noticeCtrl.text.trim();
            }

            final request = StoreItemRequest(
              name: name,
              description: descCtrl.text
                  .trim()
                  .isEmpty ? null : descCtrl.text.trim(),
              price: price,
              rarity: rarityCtrl.text
                  .trim()
                  .isEmpty ? null : rarityCtrl.text.trim(),
              type: typeCtrl.text
                  .trim()
                  .isEmpty ? null : typeCtrl.text.trim(),
              extraInfo: extraInfo.isEmpty ? null : extraInfo,
              status: status,
            );
            Navigator.pop(context, request);
          },
          child: Text(t(context, 'save')),
        ),
      ],
    );
  }
}
