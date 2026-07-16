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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Recenter GPS FAB
        FloatingActionButton.small(
          heroTag: 'map_recenter_gps',
          backgroundColor: Colors.white,
          foregroundColor: Colors.blueAccent,
          onPressed: onRecenterGps,
          child: const Icon(Icons.my_location_rounded),
        ),
        const SizedBox(height: 8),

        // 2. Map Layers Toggle Control FAB
        FloatingActionButton.small(
          heroTag: 'map_layer_menu',
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          onPressed: () => _showLayersBottomSheet(context, vis, notifier),
          child: const Icon(Icons.layers_rounded),
        ),
      ],
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
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
