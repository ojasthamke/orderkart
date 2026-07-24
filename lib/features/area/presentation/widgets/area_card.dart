/// AreaCard — Single area list item
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/area.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/full_screen_image_viewer.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/scale_on_tap.dart';
import '../../../../core/constants/app_routes.dart';

class AreaCard extends StatelessWidget {
  final Area area;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const AreaCard({
    super.key,
    required this.area,
    required this.index,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(area.color);

    return ScaleOnTap(
      onTap: onTap,
      child: GlassContainer(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Color / Image avatar
              GestureDetector(
                onTap: () {
                  final resolvedFile = AppConstants.resolveFile(area.photoPath);
                  if (area.photoPath.isNotEmpty && resolvedFile.existsSync()) {
                    FullScreenImageViewer.show(context, resolvedFile.path,
                        title: area.name);
                  }
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    image: (area.photoPath.isNotEmpty &&
                            AppConstants.resolveFile(area.photoPath)
                                .existsSync())
                        ? DecorationImage(
                            image: FileImage(
                                AppConstants.resolveFile(area.photoPath)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: (area.photoPath.isEmpty ||
                          !AppConstants.resolveFile(area.photoPath)
                              .existsSync())
                      ? Icon(Icons.map_rounded, color: color, size: 26)
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            area.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                    if (area.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        area.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Stats & Location row
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _chip(context, '${area.streetCount} Streets',
                            Icons.turn_slight_right_rounded, AppColors.primary),
                        _chip(context, '${area.customerCount} Customers',
                            Icons.people_rounded, AppColors.success),
                        if (area.mapsLocation.isNotEmpty)
                          InkWell(
                            onTap: () async {
                              final loc = area.mapsLocation.trim();
                              Uri uri;
                              if (loc.startsWith('http://') ||
                                  loc.startsWith('https://')) {
                                uri = Uri.parse(loc);
                              } else {
                                uri = Uri.parse(
                                    'https://maps.google.com/?q=${Uri.encodeComponent(loc)}');
                              }
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri,
                                    mode: LaunchMode.externalApplication);
                              }
                            },
                            child: _chip(context, '📍 Location',
                                Icons.location_on_rounded, Colors.deepOrange),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Trailing menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: AppColors.gray500),
                onSelected: (v) {
                  if (v == 'map') {
                    Navigator.of(context).pushNamed(
                      AppRoutes.areaIntelligenceMap,
                      arguments: {
                        'areaId': area.id,
                        'areaName': area.name,
                      },
                    );
                  }
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'map',
                    child: Row(
                      children: [
                        Icon(Icons.map_rounded,
                            size: 16, color: Colors.blueAccent),
                        SizedBox(width: 8),
                        Text('Map View'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
