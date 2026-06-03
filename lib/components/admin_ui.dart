part of 'package:windblog_admin_flutter/main.dart';

class AdminBreakpoints {
  const AdminBreakpoints._();

  static const double phoneMaxWidth = 700;
  static const double tabletMaxWidth = 1100;

  static bool isPhone(BuildContext context) {
    return MediaQuery.sizeOf(context).width < phoneMaxWidth;
  }

  static bool isTablet(BuildContext context) {
    double width = MediaQuery.sizeOf(context).width;
    return width >= phoneMaxWidth && width < tabletMaxWidth;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= tabletMaxWidth;
  }

  static double pagePadding(BuildContext context) {
    if (isPhone(context)) {
      return 12;
    }
    if (isTablet(context)) {
      return 16;
    }
    return 20;
  }
}

class AdminTheme {
  const AdminTheme._();

  static ThemeData build() {
    ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2563EB),
      brightness: Brightness.light,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      visualDensity: VisualDensity.standard,
      cardTheme: CardThemeData(
        elevation: 2,
        margin: EdgeInsets.zero,
        color: Colors.white,
        shadowColor: const Color(0xFF2563EB).withValues(alpha: 0.05),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF0F172A),
        surfaceTintColor: Colors.transparent,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: const Color(0xFF0F172A),
        indicatorColor: colorScheme.primaryContainer.withValues(alpha: 0.2),
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        selectedLabelTextStyle: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontWeight: FontWeight.normal,
          fontSize: 13,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(40, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(40, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class AdminPageScaffold extends StatelessWidget {
  const AdminPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions = const [],
    this.filters,
    this.footer,
    this.padding,
    this.maxContentWidth,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? filters;
  final Widget? footer;
  final double? padding;
  final double? maxContentWidth;

  @override
  Widget build(BuildContext context) {
    double resolvedPadding = padding ?? AdminBreakpoints.pagePadding(context);
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AdminPageHeader(title: title, actions: actions),
        if (filters != null) ...[const SizedBox(height: 12), filters!],
        const SizedBox(height: 12),
        Expanded(child: body),
        if (footer != null) ...[const SizedBox(height: 8), footer!],
      ],
    );

    Widget paddedContent = Padding(
      padding: EdgeInsets.all(resolvedPadding),
      child: content,
    );

    if (maxContentWidth == null) {
      return paddedContent;
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth!),
        child: paddedContent,
      ),
    );
  }
}

class _AdminPageHeader extends StatelessWidget {
  const _AdminPageHeader({required this.title, required this.actions});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    TextStyle? titleStyle = Theme.of(context).textTheme.titleLarge;
    if (AdminBreakpoints.isPhone(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: titleStyle?.copyWith(fontWeight: FontWeight.w700)),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: titleStyle?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (actions.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: actions,
          ),
      ],
    );
  }
}

class AdminToolbar extends StatelessWidget {
  const AdminToolbar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children,
        ),
      ),
    );
  }
}

class AdminStatusView extends StatelessWidget {
  const AdminStatusView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.showProgress = false,
  });

  const AdminStatusView.loading({super.key, this.title = '正在加载', this.message})
    : icon = Icons.hourglass_empty,
      action = null,
      showProgress = true;

  const AdminStatusView.empty({
    super.key,
    required this.title,
    this.message,
    this.action,
  }) : icon = Icons.inbox_outlined,
       showProgress = false;

  const AdminStatusView.error({
    super.key,
    required this.title,
    this.message,
    this.action,
  }) : icon = Icons.error_outline,
       showProgress = false;

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showProgress)
                  const CircularProgressIndicator()
                else
                  Icon(icon, size: 40, color: colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (message != null && message!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
                if (action != null) ...[const SizedBox(height: 16), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminActionButton extends StatelessWidget {
  const AdminActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isBusy = false,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isBusy;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Icon(icon, size: 18);
    if (isBusy) {
      iconWidget = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (danger) {
      return OutlinedButton.icon(
        onPressed: isBusy ? null : onPressed,
        icon: iconWidget,
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }

    return FilledButton.icon(
      onPressed: isBusy ? null : onPressed,
      icon: iconWidget,
      label: Text(label),
    );
  }
}

class AdminFeedback {
  const AdminFeedback._();

  static void success(BuildContext context, String message) {
    _show(context, message, Colors.green.shade700);
  }

  static void error(BuildContext context, String message) {
    _show(context, message, Theme.of(context).colorScheme.error);
  }

  static void info(BuildContext context, String message) {
    _show(context, message, Theme.of(context).colorScheme.primary);
  }

  static void _show(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }
}

class AdminConfirmDialog {
  const AdminConfirmDialog._();

  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmText,
    String? cancelText,
    bool danger = false,
  }) async {
    bool? result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        Color? confirmColor;
        if (danger) {
          confirmColor = Theme.of(dialogContext).colorScheme.error;
        }

        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(cancelText ?? t(dialogContext, 'cancel')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: FilledButton.styleFrom(backgroundColor: confirmColor),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return result == true;
  }
}
