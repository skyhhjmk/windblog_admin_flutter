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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
    }
  }

  Future<void> _deleteItem(StoreItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('确认删除'),
            content: Text('确定要删除物品 "${item.name}" 吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('删除'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败: $e')),
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
                label: const Text('新增物品'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _loadItems,
                icon: const Icon(Icons.refresh),
                label: const Text('刷新'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                ? const Center(child: Text('暂无物品'))
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
                            item.status == 1 ? '上架' : '下架',
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
                            '${item.price} 积分',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(item.description ?? '无描述'),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => _editItem(item),
                          child: const Text('编辑'),
                        ),
                        TextButton(
                          onPressed: () => _deleteItem(item),
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.red),
                          child: const Text('删除'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          if (totalItems > pageSize) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: currentPage > 1
                      ? () {
                    setState(() => currentPage--);
                    _loadItems();
                  }
                      : null,
                ),
                Text('第 $currentPage 页 (共 ${(totalItems / pageSize)
                    .ceil()} 页)'),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: currentPage * pageSize < totalItems
                      ? () {
                    setState(() => currentPage++);
                    _loadItems();
                  }
                      : null,
                ),
              ],
            ),
          ],
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
      title: Text(isEdit ? '编辑物品' : '新增物品'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('基础信息',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                    labelText: '物品名称 *', hintText: '如：高级会员卡'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                    labelText: '物品描述', hintText: '简短介绍物品功能'),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: priceCtrl,
                      decoration: const InputDecoration(
                          labelText: '价格 (积分) *'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: rarityCtrl,
                      decoration: const InputDecoration(
                          labelText: '稀有度颜色 (Hex, 如 #FFD700)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: typeCtrl,
                      decoration: const InputDecoration(
                          labelText: '类型 (如 item, code, file)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: '状态'),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('上架')),
                        DropdownMenuItem(value: 0, child: Text('下架')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => status = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('扩展功能 (购买后可见)', style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue)),
              const Divider(color: Colors.blue),
              TextField(
                controller: downloadUrlCtrl,
                decoration: const InputDecoration(
                  labelText: '下载链接 (download_url)',
                  prefixIcon: Icon(Icons.link, size: 20),
                  hintText: '如：网盘链接、官网链接',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: extractCodeCtrl,
                decoration: const InputDecoration(
                  labelText: '提取码/解压密码 (extract_code)',
                  prefixIcon: Icon(Icons.vpn_key_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cdkCtrl,
                decoration: const InputDecoration(
                  labelText: '卡密/序列号 (cdk)',
                  prefixIcon: Icon(Icons.password, size: 20),
                  hintText: '购买后自动发放的单条或多条文本',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noticeCtrl,
                decoration: const InputDecoration(
                  labelText: '购买须知/通知 (notice)',
                  prefixIcon: Icon(Icons.info_outline, size: 20),
                  hintText: '购买后展示给用户的额外说明文字',
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
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final name = nameCtrl.text.trim();
            final priceStr = priceCtrl.text.trim();
            final price = int.tryParse(priceStr) ?? -1;

            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('物品名称不能为空')));
              return;
            }
            if (price < 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('价格必须为有效的非负整数')));
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
          child: const Text('保存'),
        ),
      ],
    );
  }
}
