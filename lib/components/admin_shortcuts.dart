part of 'package:windblog_admin_flutter/main.dart';

/// Source-of-truth shortcut map. User customization is intentionally not
/// exposed; adding a binding requires choosing an entry here and wiring the
/// corresponding action explicitly.
class AdminShortcutDefinitions {
  const AdminShortcutDefinitions._();

  static const Map<String, String> keyByAction = <String, String>{
    'submit': 'Enter',
    'search': 'Ctrl+K',
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

class AdminShortcutHost extends StatelessWidget {
  const AdminShortcutHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            const AdminFocusSearchIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          AdminFocusSearchIntent: CallbackAction<AdminFocusSearchIntent>(
            onInvoke: (_) {
              AdminShortcutRegistry.focusSearch();
              return null;
            },
          ),
        },
        child: child,
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
