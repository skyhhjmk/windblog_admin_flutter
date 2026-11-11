import 'package:flutter/material.dart';

import '../data/models.dart';

/// Reusable component for selecting allowed visibility regions for a post or media item.
/// When [selectedRegions] is empty, the resource is accessible from all regions.
class VisibilityRegionsSelector extends StatelessWidget {
  const VisibilityRegionsSelector({
    super.key,
    required this.selectedRegions,
    required this.onChanged,
    this.regionRules = const [],
    this.isLoading = false,
    this.title = '可见区域',
    this.description = '默认所有区域均可访问；选择后仅在匹配所选区域的访问环境下可见',
  });

  final List<String> selectedRegions;
  final ValueChanged<List<String>> onChanged;
  final List<RegionRule> regionRules;
  final bool isLoading;
  final String title;
  final String description;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
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
                child: const Text('清除限制', style: TextStyle(fontSize: 12)),
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
                ? '全部区域可见'
                : '已选择 ${selectedRegions.length} 个可见区域',
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
        if (description.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }
}
