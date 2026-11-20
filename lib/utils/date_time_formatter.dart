import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

/// Shared localized date/time formatting helpers for the admin UI.
///
/// Converts backend ISO-8601 timestamps or [DateTime] values into local time
/// and supports both full localized timestamps and human-readable relative
/// labels.
class DateTimeFormatter {
  DateTimeFormatter._();

  static final DateFormat _zhDateTime = DateFormat('yyyy-MM-dd HH:mm');
  static final DateFormat _zhDateTimeSeconds = DateFormat(
    'yyyy-MM-dd HH:mm:ss',
  );
  static final DateFormat _zhDate = DateFormat('yyyy-MM-dd');
  static final DateFormat _enDateTime = DateFormat('MMM d, yyyy HH:mm');
  static final DateFormat _enDateTimeSeconds = DateFormat(
    'MMM d, yyyy HH:mm:ss',
  );
  static final DateFormat _enDate = DateFormat('MMM d, yyyy');
  static final DateFormat _timeOnly = DateFormat('HH:mm:ss');

  /// Parses a [DateTime], ISO-8601 [String], or epoch [int] into local time.
  static DateTime? parse(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    if (value is int) {
      final isSeconds = value.abs() < 1000000000000;
      return DateTime.fromMillisecondsSinceEpoch(
        isSeconds ? value * 1000 : value,
        isUtc: true,
      ).toLocal();
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    return parsed?.toLocal();
  }

  /// Formats [value] as a localized absolute date-time string.
  static String formatDateTime(
    BuildContext context,
    Object? value, {
    bool includeSeconds = false,
    String fallback = '-',
  }) {
    final local = parse(value);
    if (local == null) {
      final raw = value?.toString().trim() ?? '';
      return raw.isEmpty ? fallback : raw;
    }
    final isEnglish = _isEnglish(context);
    final fmt = isEnglish
        ? (includeSeconds ? _enDateTimeSeconds : _enDateTime)
        : (includeSeconds ? _zhDateTimeSeconds : _zhDateTime);
    return fmt.format(local);
  }

  /// Formats [value] as a localized calendar date without time-of-day.
  static String formatDate(
    BuildContext context,
    Object? value, {
    String fallback = '-',
  }) {
    final local = parse(value);
    if (local == null) {
      final raw = value?.toString().trim() ?? '';
      return raw.isEmpty ? fallback : raw;
    }
    return (_isEnglish(context) ? _enDate : _zhDate).format(local);
  }

  /// Formats [value] as `HH:mm:ss` in local time.
  static String formatTimeOnly(
    BuildContext context,
    Object? value, {
    String fallback = '-',
  }) {
    final local = parse(value);
    if (local == null) return fallback;
    return _timeOnly.format(local);
  }

  /// Formats [value] as a human-readable relative string for recent times
  /// (< 7 days) and falls back to [formatDateTime] for older timestamps.
  static String formatHuman(
    BuildContext context,
    Object? value, {
    DateTime? now,
    String fallback = '-',
  }) {
    final local = parse(value);
    if (local == null) {
      final raw = value?.toString().trim() ?? '';
      return raw.isEmpty ? fallback : raw;
    }
    final reference = (now ?? DateTime.now()).toLocal();
    final diff = reference.difference(local);

    if (diff.isNegative || diff.inMinutes < 1) {
      return t(
        context,
        'time_just_now',
        fallback: _isEnglish(context) ? 'Just now' : '刚刚',
      );
    }
    if (diff.inMinutes < 60) {
      return t(
        context,
        'time_minutes_ago',
        fallback: _isEnglish(context) ? '{n}m ago' : '{n} 分钟前',
      ).replaceAll('{n}', '${diff.inMinutes}');
    }
    if (diff.inHours < 24) {
      return t(
        context,
        'time_hours_ago',
        fallback: _isEnglish(context) ? '{n}h ago' : '{n} 小时前',
      ).replaceAll('{n}', '${diff.inHours}');
    }
    if (diff.inDays < 7) {
      return t(
        context,
        'time_days_ago',
        fallback: _isEnglish(context) ? '{n}d ago' : '{n} 天前',
      ).replaceAll('{n}', '${diff.inDays}');
    }
    return formatDateTime(context, local);
  }

  /// Renders a [Text] widget with [Tooltip] showing the exact local timestamp.
  static Widget buildTimestampText(
    BuildContext context,
    Object? value, {
    TextStyle? style,
    bool human = true,
    bool includeSeconds = false,
    String fallback = '-',
    int? maxLines,
    TextOverflow? overflow,
  }) {
    final display = human
        ? formatHuman(context, value, fallback: fallback)
        : formatDateTime(
            context,
            value,
            includeSeconds: includeSeconds,
            fallback: fallback,
          );
    final exact = formatDateTime(
      context,
      value,
      includeSeconds: true,
      fallback: fallback,
    );
    final textWidget = Text(
      display,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
    if (exact == fallback || exact == display) {
      return textWidget;
    }
    return Tooltip(message: exact, child: textWidget);
  }

  static bool _isEnglish(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    return locale?.languageCode.toLowerCase() == 'en';
  }
}
