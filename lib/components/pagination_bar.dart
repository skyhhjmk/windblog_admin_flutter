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

  void _onJump() {
    final text = _jumpCtrl.text.trim();
    if (text.isEmpty) return;
    final page = int.tryParse(text);
    if (page != null && page > 0 && page <= widget.totalPages) {
      widget.onPageChanged(page);
      _jumpCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme
        .of(context)
        .colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          // Total items
          Text(
            '${t(context, 'total')}: ${widget.totalItems}',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 16),
          // Total pages
          Text(
            t(context, 'total_pages').replaceFirst(
                '%d', widget.totalPages.toString()),
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          // Prev button
          IconButton(
            onPressed: widget.currentPage <= 1
                ? null
                : () => widget.onPageChanged(widget.currentPage - 1),
            icon: const Icon(Icons.chevron_left),
            tooltip: t(context, 'prev_page'),
          ),
          // Current page / Total pages
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
          // Next button
          IconButton(
            onPressed: widget.currentPage >= widget.totalPages
                ? null
                : () => widget.onPageChanged(widget.currentPage + 1),
            icon: const Icon(Icons.chevron_right),
            tooltip: t(context, 'next_page'),
          ),
          const SizedBox(width: 16),
          // Jump to
          Text(
            t(context, 'jump_to'),
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 50,
            child: TextField(
              controller: _jumpCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _onJump(),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            t(context, 'page'),
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _onJump,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              visualDensity: VisualDensity.compact,
            ),
            child: Text(t(context, 'go')),
          ),
        ],
      ),
    );
  }
}
