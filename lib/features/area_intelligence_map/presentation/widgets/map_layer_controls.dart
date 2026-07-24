import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../area_map_provider.dart';
import '../../domain/map_models.dart';

class MapLayerControls extends ConsumerWidget {
  final String areaId;
  final VoidCallback onRecenterGps;

  const MapLayerControls({
    super.key,
    required this.areaId,
    required this.onRecenterGps,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vis = ref.watch(mapLayerVisibilityProvider(areaId));
    final notifier = ref.read(mapLayerVisibilityProvider(areaId).notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 1. Recenter GPS Glass Button
        _buildGlassActionButton(
          context: context,
          icon: Icons.my_location_rounded,
          gradient: const [Color(0xFF0284C7), Color(0xFF38BDF8)],
          shadowColor: const Color(0xFF38BDF8).withOpacity(0.4),
          tooltip: 'Recenter My Location',
          onTap: onRecenterGps,
        ),
        const SizedBox(height: 10),

        // 2. Map Layers Toggle Glass Button
        _buildGlassActionButton(
          context: context,
          icon: Icons.layers_rounded,
          gradient: isDark
              ? [const Color(0xFF6366F1), Color(0xFFA855F7)]
              : [const Color(0xFF4F46E5), const Color(0xFF7C3AED)],
          shadowColor: const Color(0xFF8B5CF6).withOpacity(0.4),
          tooltip: 'Map Layer Controls',
          onTap: () => _showLayersBottomSheet(context, vis, notifier),
        ),
      ],
    );
  }

  Widget _buildGlassActionButton({
    required BuildContext context,
    required IconData icon,
    required List<Color> gradient,
    required Color shadowColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.35),
                    width: 1.2,
                  ),
                ),
                child: Tooltip(
                  message: tooltip,
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLayersBottomSheet(
    BuildContext context,
    MapLayerVisibility vis,
    MapLayerVisibilityNotifier notifier,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Map Layers',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: vis.baseTiles,
                      title: const Text('Show Base Map (OpenStreetMap)'),
                      secondary: const Icon(Icons.map_rounded),
                      onChanged: (_) {
                        notifier.toggleBaseTiles();
                        setState(() {});
                      },
                    ),
                    CheckboxListTile(
                      value: vis.areaBoundary,
                      title: const Text('Show Area Boundary'),
                      secondary: const Icon(Icons.crop_free_rounded),
                      onChanged: (_) {
                        notifier.toggleAreaBoundary();
                        setState(() {});
                      },
                    ),
                    CheckboxListTile(
                      value: vis.sectionBoundaries,
                      title: const Text('Show Sub-Section Boundaries'),
                      secondary: const Icon(Icons.dashboard_customize_rounded),
                      onChanged: (_) {
                        notifier.toggleSectionBoundaries();
                        setState(() {});
                      },
                    ),
                    CheckboxListTile(
                      value: vis.customerMarkers,
                      title: const Text('Show Customers'),
                      secondary: const Icon(Icons.people_alt_rounded),
                      onChanged: (_) {
                        notifier.toggleCustomerMarkers();
                        setState(() {});
                      },
                    ),
                    CheckboxListTile(
                      value: vis.deliveryMarkers,
                      title: const Text('Show Delivery Targets (Pulsing)'),
                      secondary: const Icon(Icons.shopping_bag_rounded),
                      onChanged: (_) {
                        notifier.toggleDeliveryMarkers();
                        setState(() {});
                      },
                    ),
                    CheckboxListTile(
                      value: vis.landmarks,
                      title: const Text('Show Landmarks'),
                      secondary: const Icon(Icons.pin_drop_rounded),
                      onChanged: (_) {
                        notifier.toggleLandmarks();
                        setState(() {});
                      },
                    ),
                    CheckboxListTile(
                      value: vis.labels,
                      title: const Text('Show Street Labels'),
                      secondary: const Icon(Icons.text_fields_rounded),
                      onChanged: (_) {
                        notifier.toggleLabels();
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
