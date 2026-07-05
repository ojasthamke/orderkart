// lib/features/worker/presentation/dialogs/worker_assignment_dialog.dart

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/haptics.dart';

class AssignmentItem {
  final String id;
  final String title;
  final String subtitle;
  final String? category;
  final Map<String, dynamic>? meta;

  const AssignmentItem({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.category,
    this.meta,
  });
}

class WorkerAssignmentDialog extends StatefulWidget {
  final String title;
  final List<AssignmentItem> items;
  final List<String> initialSelectedIds;

  const WorkerAssignmentDialog({
    super.key,
    required this.title,
    required this.items,
    required this.initialSelectedIds,
  });

  static Future<List<String>?> show(
    BuildContext context, {
    required String title,
    required List<AssignmentItem> items,
    required List<String> initialSelectedIds,
  }) {
    return showDialog<List<String>>(
      context: context,
      builder: (_) => WorkerAssignmentDialog(
        title: title,
        items: items,
        initialSelectedIds: initialSelectedIds,
      ),
    );
  }

  @override
  State<WorkerAssignmentDialog> createState() => _WorkerAssignmentDialogState();
}

class _WorkerAssignmentDialogState extends State<WorkerAssignmentDialog> {
  late Set<String> _selectedIds;
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.initialSelectedIds);
  }

  List<String> get _categories {
    final cats = widget.items
        .map((e) => e.category)
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    cats.sort();
    return cats;
  }

  List<AssignmentItem> get _filteredItems {
    return widget.items.where((item) {
      final matchesQuery = _searchQuery.isEmpty ||
          item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.subtitle.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCat = _selectedCategory == null || item.category == _selectedCategory;
      return matchesQuery && matchesCat;
    }).toList();
  }

  void _selectAll() {
    AppHaptics.buttonClick();
    setState(() {
      for (final item in _filteredItems) {
        _selectedIds.add(item.id);
      }
    });
  }

  void _deselectAll() {
    AppHaptics.buttonClick();
    setState(() {
      for (final item in _filteredItems) {
        _selectedIds.remove(item.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;
    final categories = _categories;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // --- HEADER ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.check_box_outlined, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // --- SEARCH BAR ---
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search ${widget.title.replaceAll('Assign ', '')}...',
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.gray500),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: AppColors.gray100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // --- CATEGORY FILTERS CHIPS (IF ANY) ---
            if (categories.isNotEmpty) ...[
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    FilterChip(
                      selected: _selectedCategory == null,
                      label: const Text('All'),
                      onSelected: (_) => setState(() => _selectedCategory = null),
                      selectedColor: AppColors.primarySurface,
                      checkmarkColor: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    ...categories.map(
                      (cat) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          selected: _selectedCategory == cat,
                          label: Text(cat),
                          onSelected: (sel) => setState(() => _selectedCategory = sel ? cat : null),
                          selectedColor: AppColors.primarySurface,
                          checkmarkColor: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // --- ACTION BAR (Select All / Deselect All / Count Badge) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_selectedIds.length} of ${widget.items.length} Selected',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _selectAll,
                      icon: const Icon(Icons.select_all_rounded, size: 16),
                      label: const Text('Select All', style: TextStyle(fontSize: 12)),
                    ),
                    TextButton.icon(
                      onPressed: _deselectAll,
                      icon: const Icon(Icons.deselect_rounded, size: 16),
                      label: const Text('Clear', style: TextStyle(fontSize: 12, color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 16),

            // --- LIST OF ITEMS ---
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No matching records found.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                      itemBuilder: (ctx, index) {
                        final item = filtered[index];
                        final isSelected = _selectedIds.contains(item.id);

                        return CheckboxListTile(
                          value: isSelected,
                          activeColor: AppColors.primary,
                          title: Text(
                            item.title,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: item.subtitle.isNotEmpty
                              ? Text(
                                  item.subtitle,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                )
                              : null,
                          secondary: item.category != null && item.category!.isNotEmpty
                              ? Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.gray200,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.category!,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                                  ),
                                )
                              : null,
                          onChanged: (val) {
                            AppHaptics.buttonClick();
                            setState(() {
                              if (val == true) {
                                _selectedIds.add(item.id);
                              } else {
                                _selectedIds.remove(item.id);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),

            const SizedBox(height: 12),

            // --- BOTTOM ACTIONS ---
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      AppHaptics.buttonClick();
                      Navigator.pop(context, _selectedIds.toList());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Save ${widget.title.replaceAll('Assign ', '')}'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
