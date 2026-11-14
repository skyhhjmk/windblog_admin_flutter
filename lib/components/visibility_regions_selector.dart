import 'package:flutter/material.dart';

import '../data/models.dart';
import '../l10n/app_localizations.dart';

/// Reusable component for selecting allowed visibility regions for a post or media item.
/// When [selectedRegions] is empty, the resource is accessible from all regions.
class VisibilityRegionsSelector extends StatelessWidget {
  const VisibilityRegionsSelector({
    super.key,
    required this.selectedRegions,
    required this.onChanged,
    this.regionRules = const [],
    this.isLoading = false,
    this.title,
    this.description,
  });

  final List<String> selectedRegions;
  final ValueChanged<List<String>> onChanged;
  final List<RegionRule> regionRules;
  final bool isLoading;
  final String? title;
  final String? description;

  List<String> get _availableRegionCodes {
    final codes = <String>[];
    for (final r in BlogRegion.values) {
      codes.add(r.code);
    }
    for (final rule in regionRules) {
      if (!codes.contains(rule.region)) {
        codes.add(rule.region);
      }
    }
    for (final r in selectedRegions) {
      if (!codes.contains(r)) {
        codes.add(r);
      }
    }
    return codes;
  }

  String _displayNameFor(String code) {
    for (final rule in regionRules) {
      if (rule.region == code && rule.name.trim().isNotEmpty) {
        return '${rule.name} ($code)';
      }
    }
    final blogRegion = BlogRegion.fromCode(code);
    if (blogRegion != BlogRegion.global || code.toLowerCase() == 'global') {
      return blogRegion.displayName;
    }
    return code;
  }

  void _toggleRegion(String region, bool selected) {
    final next = List<String>.from(selectedRegions);
    if (selected) {
      if (!next.contains(region)) {
        next.add(region);
      }
    } else {
      next.remove(region);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final available = _availableRegionCodes;
    final displayTitle =
        title ?? t(context, 'visibility_regions', fallback: '可见区域');
    final displayDesc =
        description ??
        t(
          context,
          'visibility_regions_desc',
          fallback: '默认所有区域均可访问；选择后仅在匹配所选区域的访问环境下可见',
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                displayTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            if (selectedRegions.isNotEmpty)
              TextButton(
                onPressed: () => onChanged(const []),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  t(context, 'visibility_regions_clear', fallback: '清除限制'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          )
        else ...[
          Text(
            selectedRegions.isEmpty
                ? t(context, 'visibility_regions_all', fallback: '全部区域可见')
                : t(
                    context,
                    'visibility_regions_selected_count',
                    fallback: '已选择 %d 个可见区域',
                  ).replaceAll('%d', selectedRegions.length.toString()),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: available.map((region) {
              final selected = selectedRegions.contains(region);
              return FilterChip(
                label: Text(
                  _displayNameFor(region),
                  style: const TextStyle(fontSize: 12),
                ),
                selected: selected,
                onSelected: (val) => _toggleRegion(region, val),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
        if (displayDesc.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            displayDesc,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }
}
