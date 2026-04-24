import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import '../data/models.dart';

class TutorialEditor extends StatefulWidget {
  const TutorialEditor({
    super.key,
    required this.initialBlocks,
    required this.levels,
    required this.onChanged,
  });

  final Map<String, List<TutorialBlock>>? initialBlocks;
  final List<TutorialLevelDef>? levels;
  final ValueChanged<Map<String, List<TutorialBlock>>> onChanged;

  @override
  State<TutorialEditor> createState() => _TutorialEditorState();
}

class _TutorialEditorState extends State<TutorialEditor> {
  late EditorState _editorState;
  final FocusNode _focusNode = FocusNode();
  late EditorScrollController _scrollController;
  int _currentSelectionLevel = 0;
  
  @override
  void initState() {
    super.initState();

    // 简化处理：直接用空编辑器初始化，避免文档结构问题导致无法输入
    // 以后再完善文档转换逻辑
    _editorState = EditorState.blank(withInitialText: true);

    _scrollController = EditorScrollController(editorState: _editorState);
    
    // Auto-focus the editor after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });

    // Listen to selection changes to update toolbar
    _editorState.selectionNotifier.addListener(_updateCurrentLevelFromSelection);

    // Listen to changes to report back (简化数据处理，只保存基本结构)
    _editorState.transactionStream.listen((event) {
      if (!mounted) return;
      final json = _editorState.document.toJson();
      final blocks = _mapAppFlowyToTutorialBlocks(json['blocks'] as List? ?? []);
      
      widget.onChanged({
        'zh-cn': blocks,
      });
    });
  }

  void _updateCurrentLevelFromSelection() {
    final selection = _editorState.selection;
    if (selection == null || !selection.isCollapsed) {
      return;
    }

    final node = _editorState.getNodeAtPath(selection.start.path);
    if (node != null) {
      final level = node.attributes['level'] as int? ?? 0;
      // 确保 level 在可用选项中
      final availableLevels = _getAvailableLevels();
      final validLevel = availableLevels.contains(level) ? level : 0;
      if (validLevel != _currentSelectionLevel) {
        setState(() {
          _currentSelectionLevel = validLevel;
        });
      }
    }
  }

  List<int> _getAvailableLevels() {
    final levels = [0];
    if (widget.levels != null) {
      for (final l in widget.levels!) {
        if (!levels.contains(l.level)) {
          levels.add(l.level);
        }
      }
    }
    return levels;
  }

  List<DropdownMenuItem<int>> _buildDropdownItems() {
    final items = <DropdownMenuItem<int>>[];
    items.add(const DropdownMenuItem(
      value: 0,
      child: Text('Default (0)', style: TextStyle(fontSize: 13)),
    ));
    if (widget.levels != null) {
      final addedLevels = <int>{0};
      for (final l in widget.levels!) {
        if (!addedLevels.contains(l.level)) {
          addedLevels.add(l.level);
          items.add(DropdownMenuItem(
            value: l.level,
            child: Text('Level ${l.level} (${l.name})', style: TextStyle(fontSize: 13)),
          ));
        }
      }
    }
    return items;
  }

  List<TutorialBlock> _mapAppFlowyToTutorialBlocks(List blocks) {
    return blocks.map((b) {
      final map = b as Map<String, dynamic>;
      final type = map['type']?.toString() ?? 'paragraph';
      final attributes = map['attributes'] as Map<String, dynamic>? ?? {};
      
      return TutorialBlock(
        type: type == 'paragraph' ? 'p' : type,
        level: attributes['level'] is int ? attributes['level'] as int : 0,
        data: attributes,
        children: _mapAppFlowyToTutorialBlocks(map['children'] as List? ?? []),
      );
    }).toList();
  }

  @override
  void dispose() {
    _editorState.selectionNotifier.removeListener(_updateCurrentLevelFromSelection);
    _focusNode.dispose();
    _editorState.dispose();
    super.dispose();
  }

  void _updateLevel(int level) {
    final selection = _editorState.selection;
    if (selection == null) return;

    final transaction = _editorState.transaction;
    final startPath = selection.start.path;
    final endPath = selection.end.path;

    for (int i = startPath.last; i <= endPath.last; i++) {
      final path = [...startPath.sublist(0, startPath.length - 1), i];
      final node = _editorState.getNodeAtPath(path);
      if (node != null) {
        transaction.updateNode(
          node,
          {
            'level': level,
          },
        );
      }
    }
    _editorState.apply(transaction);
    setState(() {
      _currentSelectionLevel = level;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              IconButton(
                icon: const Icon(Icons.format_bold),
                onPressed: () {
                   _editorState.toggleAttribute(AppFlowyRichTextKeys.bold);
                },
                tooltip: 'Bold',
              ),
              IconButton(
                icon: const Icon(Icons.format_italic),
                onPressed: () {
                   _editorState.toggleAttribute(AppFlowyRichTextKeys.italic);
                },
                tooltip: 'Italic',
              ),
              const SizedBox(
                height: 24,
                child: VerticalDivider(width: 1, indent: 4, endIndent: 4),
              ),
              // Level selection
              const Text('Block Level:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              DropdownButton<int>(
                value: _currentSelectionLevel,
                items: _buildDropdownItems(),
                onChanged: (v) {
                  if (v != null) _updateLevel(v);
                },
                underline: const SizedBox(),
              ),
            ],
          ),
        ),
        // The actual editor
        Expanded(
          child: AppFlowyEditor(
            editorState: _editorState,
            focusNode: _focusNode,
            editorScrollController: _scrollController,
            editable: true,
          ),
        ),
      ],
    );
  }
}
