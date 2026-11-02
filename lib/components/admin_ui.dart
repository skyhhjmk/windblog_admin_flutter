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

  static const Color brandColor = Color(0xFF2563EB);
  static const Color navigationColor = Color(0xFF0F172A);

  static ThemeData build({Brightness brightness = Brightness.light}) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: brandColor,
      brightness: brightness,
    );

    final scaffoldBg = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final inputBorder = isDark
        ? const Color(0xFF475569)
        : const Color(0xFFCBD5E1);
    final railBg = isDark ? const Color(0xFF0B101D) : navigationColor;

    return ThemeData(
      colorScheme: colorScheme,
      brightness: brightness,
      useMaterial3: true,
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: colorScheme.primary.withValues(alpha: 0.28),
        selectionHandleColor: colorScheme.primary,
        cursorColor: colorScheme.primary,
      ),
      scaffoldBackgroundColor: scaffoldBg,
      visualDensity: VisualDensity.standard,
      cardTheme: CardThemeData(
        elevation: isDark ? 0 : 2,
        margin: EdgeInsets.zero,
        color: cardBg,
        shadowColor: isDark
            ? Colors.black.withValues(alpha: 0.3)
            : brandColor.withValues(alpha: 0.05),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cardBorder),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: cardBg,
        foregroundColor: isDark
            ? const Color(0xFFF8FAFC)
            : const Color(0xFF0F172A),
        surfaceTintColor: Colors.transparent,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: railBg,
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
        fillColor: cardBg,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: DividerThemeData(color: cardBorder, thickness: 1),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: TextStyle(
          fontWeight: FontWeight.bold,
          color: colorScheme.primary,
        ),
        headingRowColor: WidgetStateProperty.all(
          colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.05),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(40, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(40, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: const TextStyle(color: Colors.white),
      ),
    );
  }

  static ThemeData light() => build(brightness: Brightness.light);
  static ThemeData dark() => build(brightness: Brightness.dark);
}

class ThemeModePopupButton extends StatelessWidget {
  const ThemeModePopupButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppThemeController.instance,
      builder: (context, _) {
        final mode = AppThemeController.instance.themeMode;
        final IconData icon;
        switch (mode) {
          case ThemeMode.system:
            icon = Icons.brightness_auto_outlined;
          case ThemeMode.light:
            icon = Icons.light_mode_outlined;
          case ThemeMode.dark:
            icon = Icons.dark_mode_outlined;
        }

        return PopupMenuButton<ThemeMode>(
          tooltip: t(context, 'theme_mode'),
          icon: Icon(icon, size: 20),
          initialValue: mode,
          onSelected: (selectedMode) {
            AppThemeController.instance.setThemeMode(selectedMode);
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: ThemeMode.system,
              child: Row(
                children: [
                  const Icon(Icons.brightness_auto_outlined, size: 18),
                  const SizedBox(width: 10),
                  Text(t(context, 'theme_system')),
                  if (mode == ThemeMode.system) ...[
                    const Spacer(),
                    Icon(
                      Icons.check,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuItem(
              value: ThemeMode.light,
              child: Row(
                children: [
                  const Icon(Icons.light_mode_outlined, size: 18),
                  const SizedBox(width: 10),
                  Text(t(context, 'theme_light')),
                  if (mode == ThemeMode.light) ...[
                    const Spacer(),
                    Icon(
                      Icons.check,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuItem(
              value: ThemeMode.dark,
              child: Row(
                children: [
                  const Icon(Icons.dark_mode_outlined, size: 18),
                  const SizedBox(width: 10),
                  Text(t(context, 'theme_dark')),
                  if (mode == ThemeMode.dark) ...[
                    const Spacer(),
                    Icon(
                      Icons.check,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
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
        if (!AdminBreakpoints.isPhone(context) || actions.isNotEmpty)
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
      return Align(
        alignment: Alignment.centerRight,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: actions,
        ),
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
        padding: EdgeInsets.all(AdminBreakpoints.isPhone(context) ? 8 : 12),
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
                      color: colorScheme.onSurfaceVariant,
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
    final iconWidget = AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: isBusy
          ? const SizedBox(
              key: ValueKey('busy'),
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, key: const ValueKey('idle'), size: 18),
    );

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

  static void showTransient(
    BuildContext context, {
    required String message,
    String title = '提示',
    AdminNotificationSeverity severity = AdminNotificationSeverity.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final controller = AdminNotificationScope.maybeOf(context);
    if (controller != null) {
      controller.showTransient(
        message: message,
        title: title,
        severity: severity,
        actionLabel: actionLabel,
        onAction: onAction,
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: actionLabel == null || onAction == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction),
      ),
    );
  }

  static void showSnackBar(BuildContext context, SnackBar snackBar) {
    final controller = AdminNotificationScope.maybeOf(context);
    if (controller == null) {
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
      return;
    }
    String message = snackBar.content is Text
        ? ((snackBar.content as Text).data ?? snackBar.content.toString())
        : snackBar.content.toString();
    final backgroundColor = snackBar.backgroundColor;
    AdminNotificationSeverity severity = AdminNotificationSeverity.info;
    if (backgroundColor != null) {
      if (backgroundColor == Colors.green ||
          backgroundColor == Colors.green.shade700 ||
          backgroundColor == Colors.green.shade800) {
        severity = AdminNotificationSeverity.success;
      } else if (backgroundColor == Colors.orange ||
          backgroundColor == Colors.orange.shade800) {
        severity = AdminNotificationSeverity.warning;
      } else if (backgroundColor.computeLuminance() < 0.25) {
        severity = AdminNotificationSeverity.error;
      } else if (backgroundColor.computeLuminance() > 0.65) {
        severity = AdminNotificationSeverity.success;
      }
    }
    controller.showTransient(
      message: message,
      severity: severity,
      actionLabel: snackBar.action?.label,
      onAction: snackBar.action?.onPressed,
    );
  }

  static void _show(BuildContext context, String message, Color color) {
    final controller = AdminNotificationScope.maybeOf(context);
    if (controller == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
      return;
    }
    AdminNotificationSeverity severity = AdminNotificationSeverity.info;
    if (color == Colors.green.shade700) {
      severity = AdminNotificationSeverity.success;
    } else if (color == Theme.of(context).colorScheme.error) {
      severity = AdminNotificationSeverity.error;
    }
    controller.showTransient(message: message, severity: severity);
  }
}

class AdminRequestRunner {
  const AdminRequestRunner._();

  static Future<T?> run<T>({
    required BuildContext context,
    required bool mounted,
    required VoidCallback onAuthError,
    required Future<T> Function() task,
    required String Function(Object error) errorMessageBuilder,
  }) async {
    try {
      return await task();
    } on UnauthorizedException {
      onAuthError();
      return null;
    } catch (error) {
      if (mounted) {
        AdminFeedback.error(context, errorMessageBuilder(error));
      }
      return null;
    }
  }

  static Future<void> runVoid({
    required BuildContext context,
    required bool mounted,
    required VoidCallback onAuthError,
    required Future<void> Function() task,
    required String Function(Object error) errorMessageBuilder,
  }) async {
    await run<void>(
      context: context,
      mounted: mounted,
      onAuthError: onAuthError,
      task: task,
      errorMessageBuilder: errorMessageBuilder,
    );
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
