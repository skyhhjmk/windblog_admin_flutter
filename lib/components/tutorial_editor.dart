
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
  
  @override
  void initState() {
    super.initState();
    
    // 1. Determine initial document
    Document document;
    if (widget.initialBlocks != null && widget.initialBlocks!.isNotEmpty) {
       final blocks = widget.initialBlocks!.values.first;
       // Note: _mapTutorialBlocksToAppFlowyDocument uses DateTime for IDs now, so it doesn't need _editorState yet
       document = _mapTutorialBlocksToAppFlowyDocument(blocks);
    } else {
       document = Document.blank();
    }

    // 2. Initialize state and controller exactly once
    _editorState = EditorState(document: document);
    _scrollController = EditorScrollController(editorState: _editorState);
    
    // Auto-focus the editor after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
    // Listen to changes to report back
    _editorState.transactionStream.listen((event) {
      final json = _editorState.document.toJson();
      final blocks = _mapAppFlowyToTutorialBlocks(json['blocks'] as List? ?? []);
      
      widget.onChanged({
        'zh-cn': blocks, // Default to zh-cn for now
      });
    });
  }

  Document _mapTutorialBlocksToAppFlowyDocument(List<TutorialBlock> blocks) {
    return Document(
      root: Node(
        type: 'page',
        id: 'root',
        children: blocks.map((b) => _tutorialBlockToNode(b)).toList(),
      ),
    );
  }

  Node _tutorialBlockToNode(TutorialBlock block) {
    return Node(
      id: '${DateTime.now().microsecondsSinceEpoch}_${block.hashCode}',
      type: block.type == 'p' ? 'paragraph' : block.type,
      attributes: {
        'level': block.level ?? 0,
        ...block.data ?? {},
      },
      children: block.children?.map((c) => _tutorialBlockToNode(c)).toList() ?? [],
    );
  }

  List<TutorialBlock> _mapAppFlowyToTutorialBlocks(List blocks) {
    return blocks.map((b) {
      final map = b as Map<String, dynamic>;
      final type = map['type']?.toString() ?? 'p';
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
    _focusNode.dispose();
    _editorState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A simple toolbar placeholder
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.format_bold),
                onPressed: () {},
                tooltip: 'Bold',
              ),
              IconButton(
                icon: const Icon(Icons.format_list_bulleted),
                onPressed: () {},
                tooltip: 'List',
              ),
              const Spacer(),
              // Level selection placeholder
              DropdownButton<int>(
                value: 0,
                items: [
                  const DropdownMenuItem(value: 0, child: Text('Level 0 (Default)')),
                  if (widget.levels != null)
                    ...widget.levels!
                        .where((l) => l.level != 0) // Avoid duplicate 0
                        .map((l) => DropdownMenuItem(
                              value: l.level,
                              child: Text('Level ${l.level} (${l.name})'),
                            )),
                ],
                onChanged: (v) {},
                underline: const SizedBox(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // The actual editor
        Expanded(
          child: GestureDetector(
            onTap: () => _focusNode.requestFocus(),
            child: AppFlowyEditor(
              editorState: _editorState,
              focusNode: _focusNode,
              editorScrollController: _scrollController,
              editable: true,
            ),
          ),
        ),
      ],
    );
  }
}
