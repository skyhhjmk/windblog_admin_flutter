part of 'package:windblog_admin_flutter/main.dart';

/// Source-of-truth shortcut map. User customization is intentionally not
/// exposed; adding a binding requires choosing an entry here and wiring the
/// corresponding action explicitly.
class AdminShortcutDefinitions {
  const AdminShortcutDefinitions._();

  static const Map<String, String> keyByAction = <String, String>{
    'submit': 'Enter',
    'search': 'Ctrl+K',
    'developer_options': '`',
  };
}

/// The admin shortcut registry is deliberately application-scoped. It only
/// contains live widgets in the current route and never installs an OS-level
/// global hotkey.
class AdminShortcutRegistry {
  AdminShortcutRegistry._();

  static final Set<FocusNode> _searchNodes = <FocusNode>{};

  static void registerSearch(FocusNode node) => _searchNodes.add(node);

  static void unregisterSearch(FocusNode node) => _searchNodes.remove(node);

  static bool focusSearch() {
    for (final node in _searchNodes.toList()) {
      if (node.context != null && node.canRequestFocus) {
        node.requestFocus();
        return true;
      }
    }
    return false;
  }
}

class AdminFocusSearchIntent extends Intent {
  const AdminFocusSearchIntent();
}

class AdminOpenDeveloperOptionsIntent extends Intent {
  const AdminOpenDeveloperOptionsIntent();
}

class AdminShortcutHost extends StatefulWidget {
  const AdminShortcutHost({super.key, required this.child});

  final Widget child;

  @override
  State<AdminShortcutHost> createState() => _AdminShortcutHostState();
}

class _AdminShortcutHostState extends State<AdminShortcutHost> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleHardwareKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleHardwareKey);
    super.dispose();
  }

  bool _isFocusedInMultilineEditableText() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return false;
    EditableText? editable;
    if (focusContext.widget is EditableText) {
      editable = focusContext.widget as EditableText;
    } else {
      editable = focusContext.findAncestorWidgetOfExactType<EditableText>();
    }
    if (editable == null) return false;
    return editable.maxLines == null || editable.maxLines! > 1;
  }

  bool _handleHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final isBackquote =
        event.logicalKey == LogicalKeyboardKey.backquote ||
        event.physicalKey == PhysicalKeyboardKey.backquote ||
        event.character == '`';
    if (!isBackquote) return false;

    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final isShiftPressed =
        pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);
    if (isShiftPressed) return false;

    final isControlOrMeta =
        pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);

    if (!isControlOrMeta && _isFocusedInMultilineEditableText()) {
      return false;
    }

    if (!mounted || AdminDeveloperOptions.isDialogOpen) return false;
    AdminDeveloperOptions.show(context);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            const AdminFocusSearchIntent(),
        const SingleActivator(LogicalKeyboardKey.backquote):
            const AdminOpenDeveloperOptionsIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          AdminFocusSearchIntent: CallbackAction<AdminFocusSearchIntent>(
            onInvoke: (_) {
              AdminShortcutRegistry.focusSearch();
              return null;
            },
          ),
          AdminOpenDeveloperOptionsIntent:
              CallbackAction<AdminOpenDeveloperOptionsIntent>(
                onInvoke: (_) {
                  if (!AdminDeveloperOptions.isDialogOpen &&
                      !_isFocusedInMultilineEditableText()) {
                    AdminDeveloperOptions.show(context);
                  }
                  return null;
                },
              ),
        },
        child: widget.child,
      ),
    );
  }
}

/// A search field that participates in the current route's Ctrl+K target.
class AdminShortcutSearchField extends StatefulWidget {
  const AdminShortcutSearchField({
    super.key,
    this.controller,
    this.decoration,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final InputDecoration? decoration;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  State<AdminShortcutSearchField> createState() =>
      _AdminShortcutSearchFieldState();
}

class _AdminShortcutSearchFieldState extends State<AdminShortcutSearchField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'admin-search');
    AdminShortcutRegistry.registerSearch(_focusNode);
  }

  @override
  void dispose() {
    AdminShortcutRegistry.unregisterSearch(_focusNode);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      decoration: widget.decoration?.copyWith(
        suffixText:
            widget.decoration?.suffixText ??
            AdminShortcutDefinitions.keyByAction['search'],
      ),
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    );
  }
}

class AdminShortcutText extends StatelessWidget {
  const AdminShortcutText(this.label, this.shortcut, {super.key, this.style});

  final String label;
  final String shortcut;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: label,
        style: style,
        children: <InlineSpan>[
          TextSpan(
            text: '（$shortcut）',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
          ),
        ],
      ),
    );
  }
}
