part of 'package:windblog_admin_flutter/main.dart';

class PaginationBar extends StatefulWidget {
  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.onPageChanged,
    this.pageSize,
  });

  final int currentPage;
  final int totalPages;
  final int totalItems;
  final ValueChanged<int> onPageChanged;
  final int? pageSize;

  @override
  State<PaginationBar> createState() => _PaginationBarState();
}

class _PaginationBarState extends State<PaginationBar> {
  late final TextEditingController _jumpCtrl;
  String? _jumpError;

  @override
  void initState() {
    super.initState();
    _jumpCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _jumpCtrl.dispose();
    super.dispose();
  }

  void _onJump({BuildContext? dialogContext, StateSetter? updateDialog}) {
    void updateError(String? error) {
      if (updateDialog != null) {
        updateDialog(() => _jumpError = error);
      } else {
        setState(() => _jumpError = error);
      }
    }

    final text = _jumpCtrl.text.trim();
    if (text.isEmpty) {
      updateError(null);
      return;
    }
    final page = int.tryParse(text);
    if (page != null && page > 0 && page <= widget.totalPages) {
      updateError(null);
      if (dialogContext != null) Navigator.pop(dialogContext);
      widget.onPageChanged(page);
      _jumpCtrl.clear();
    } else {
      updateError(t(context, 'invalid_page'));
    }
  }

  Future<void> _showPhoneJumpDialog() async {
    _jumpCtrl.clear();
    _jumpError = null;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(t(context, 'jump_to')),
          content: TextField(
            controller: _jumpCtrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '${t(context, 'page')} (1-${widget.totalPages})',
              isDense: true,
              errorText: _jumpError,
            ),
            onChanged: (_) {
              if (_jumpError != null) {
                setDialogState(() => _jumpError = null);
              }
            },
            onSubmitted: (_) => _onJump(
              dialogContext: dialogContext,
              updateDialog: setDialogState,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(t(context, 'cancel')),
            ),
            FilledButton(
              onPressed: () => _onJump(
                dialogContext: dialogContext,
                updateDialog: setDialogState,
              ),
              child: Text(t(context, 'go')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhonePagination(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${t(context, 'total')}: ${widget.totalItems}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: widget.currentPage <= 1
                ? null
                : () => widget.onPageChanged(widget.currentPage - 1),
            icon: const Icon(Icons.chevron_left),
            tooltip: t(context, 'prev_page'),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${widget.currentPage} / ${widget.totalPages}',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: widget.currentPage >= widget.totalPages
                ? null
                : () => widget.onPageChanged(widget.currentPage + 1),
            icon: const Icon(Icons.chevron_right),
            tooltip: t(context, 'next_page'),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: widget.totalPages <= 1 ? null : _showPhoneJumpDialog,
            icon: const Icon(Icons.find_in_page_outlined),
            tooltip: t(context, 'jump_to'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (AdminBreakpoints.isPhone(context)) {
      return _buildPhonePagination(colorScheme);
    }

    final summaryItems = [
      Text(
        '${t(context, 'total')}: ${widget.totalItems}',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
      Text(
        t(
          context,
          'total_pages',
        ).replaceFirst('%d', widget.totalPages.toString()),
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
    ];

    final controlItems = [
      IconButton(
        onPressed: widget.currentPage <= 1
            ? null
            : () => widget.onPageChanged(widget.currentPage - 1),
        icon: const Icon(Icons.chevron_left),
        tooltip: t(context, 'prev_page'),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${widget.currentPage} / ${widget.totalPages}',
          style: TextStyle(
            color: colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
      IconButton(
        onPressed: widget.currentPage >= widget.totalPages
            ? null
            : () => widget.onPageChanged(widget.currentPage + 1),
        icon: const Icon(Icons.chevron_right),
        tooltip: t(context, 'next_page'),
      ),
      Text(
        t(context, 'jump_to'),
        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
      ),
      SizedBox(
        width: _jumpError == null ? 56 : 92,
        child: TextField(
          controller: _jumpCtrl,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
            border: OutlineInputBorder(),
            errorText: _jumpError,
            errorStyle: TextStyle(fontSize: 10),
          ),
          onChanged: (_) {
            if (_jumpError != null) setState(() => _jumpError = null);
          },
          onSubmitted: (_) => _onJump(),
        ),
      ),
      Text(
        t(context, 'page'),
        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
      ),
      OutlinedButton(
        onPressed: _onJump,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          visualDensity: VisualDensity.compact,
        ),
        child: Text(t(context, 'go')),
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Wrap(spacing: 16, runSpacing: 8, children: summaryItems),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: controlItems,
          ),
        ],
      ),
    );
  }
}
