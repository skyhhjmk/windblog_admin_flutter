part of 'package:windblog_admin_flutter/main.dart';

class AdminPaginationController extends ChangeNotifier {
  AdminPaginationController({
    int initialPage = 1,
    int pageSize = 20,
    int totalItems = 0,
  }) : _currentPage = initialPage < 1 ? 1 : initialPage,
       _pageSize = pageSize < 1 ? 20 : pageSize,
       _totalItems = totalItems < 0 ? 0 : totalItems;

  int _currentPage;
  int _pageSize;
  int _totalItems;

  int get currentPage => _currentPage;
  int get pageSize => _pageSize;
  int get totalItems => _totalItems;

  int get totalPages =>
      _totalItems <= 0 ? 1 : ((_totalItems + _pageSize - 1) ~/ _pageSize);

  bool get hasPrevious => _currentPage > 1;
  bool get hasNext => _currentPage < totalPages;

  void setPage(int page) {
    final nextPage = _totalItems > 0
        ? page.clamp(1, totalPages)
        : (page < 1 ? 1 : page);
    if (nextPage == _currentPage) return;
    _currentPage = nextPage;
    notifyListeners();
  }

  void resetToFirstPage() {
    setPage(1);
  }

  void updateTotal(int total, {int? page, int? pageSize}) {
    final nextPageSize =
        (pageSize != null && pageSize > 0) ? pageSize : _pageSize;
    final nextTotal = total < 0 ? 0 : total;
    final nextTotalPages =
        nextTotal <= 0 ? 1 : ((nextTotal + nextPageSize - 1) ~/ nextPageSize);
    final nextPage = (page ?? _currentPage).clamp(1, nextTotalPages);
    if (nextTotal == _totalItems &&
        nextPageSize == _pageSize &&
        nextPage == _currentPage) {
      return;
    }
    _totalItems = nextTotal;
    _pageSize = nextPageSize;
    _currentPage = nextPage;
    notifyListeners();
  }

  List<T> slice<T>(List<T> items) {
    if (items.isEmpty) return const [];
    final start = (_currentPage - 1) * _pageSize;
    if (start >= items.length) {
      return const [];
    }
    final end = (start + _pageSize).clamp(0, items.length);
    return items.sublist(start, end);
  }
}

class PaginationBar extends StatefulWidget {
  const PaginationBar({
    super.key,
    this.controller,
    int? currentPage,
    int? totalPages,
    int? totalItems,
    this.onPageChanged,
    this.pageSize,
  }) : assert(
         controller != null ||
             (currentPage != null &&
                 totalPages != null &&
                 totalItems != null &&
                 onPageChanged != null),
         'Either controller or explicit pagination parameters must be provided',
       ),
       _currentPage = currentPage ?? 1,
       _totalPages = totalPages ?? 1,
       _totalItems = totalItems ?? 0;

  final AdminPaginationController? controller;
  final int _currentPage;
  final int _totalPages;
  final int _totalItems;
  final ValueChanged<int>? onPageChanged;
  final int? pageSize;

  @override
  State<PaginationBar> createState() => _PaginationBarState();
}

class _PaginationBarState extends State<PaginationBar> {
  late final TextEditingController _jumpCtrl;
  String? _jumpError;

  int get _effectiveCurrentPage =>
      widget.controller?.currentPage ?? widget._currentPage;

  int get _effectiveTotalPages =>
      widget.controller?.totalPages ?? widget._totalPages;

  int get _effectiveTotalItems =>
      widget.controller?.totalItems ?? widget._totalItems;

  void _selectPage(int page) {
    widget.controller?.setPage(page);
    widget.onPageChanged?.call(page);
  }

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
    if (page != null && page > 0 && page <= _effectiveTotalPages) {
      updateError(null);
      if (dialogContext != null) Navigator.pop(dialogContext);
      _selectPage(page);
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
              labelText: '${t(context, 'page')} (1-$_effectiveTotalPages)',
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
    final currentPage = _effectiveCurrentPage;
    final totalPages = _effectiveTotalPages;
    final totalItems = _effectiveTotalItems;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${t(context, 'total')}: $totalItems',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: currentPage <= 1
                ? null
                : () => _selectPage(currentPage - 1),
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
              '$currentPage / $totalPages',
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: currentPage >= totalPages
                ? null
                : () => _selectPage(currentPage + 1),
            icon: const Icon(Icons.chevron_right),
            tooltip: t(context, 'next_page'),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: totalPages <= 1 ? null : _showPhoneJumpDialog,
            icon: const Icon(Icons.find_in_page_outlined),
            tooltip: t(context, 'jump_to'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (controller == null) {
      return _buildResponsivePagination(context);
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _buildResponsivePagination(context),
    );
  }

  Widget _buildResponsivePagination(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (AdminBreakpoints.isPhone(context)) {
      return _buildPhonePagination(colorScheme);
    }

    final currentPage = _effectiveCurrentPage;
    final totalPages = _effectiveTotalPages;
    final totalItems = _effectiveTotalItems;

    final summaryItems = [
      Text(
        '${t(context, 'total')}: $totalItems',
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
      ),
      Text(
        t(
          context,
          'total_pages',
        ).replaceFirst('%d', totalPages.toString()),
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
      ),
    ];

    final controlItems = [
      IconButton(
        onPressed: currentPage <= 1 ? null : () => _selectPage(currentPage - 1),
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
          '$currentPage / $totalPages',
          style: TextStyle(
            color: colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
      IconButton(
        onPressed: currentPage >= totalPages
            ? null
            : () => _selectPage(currentPage + 1),
        icon: const Icon(Icons.chevron_right),
        tooltip: t(context, 'next_page'),
      ),
      Text(
        t(context, 'jump_to'),
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
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
        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
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
      width: double.infinity,
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
