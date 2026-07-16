import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

class MapPinPickerScreen extends StatefulWidget {
  final LatLng? initialPosition;

  const MapPinPickerScreen({
    super.key,
    this.initialPosition,
  });

  @override
  State<MapPinPickerScreen> createState() => _MapPinPickerScreenState();
}

class _MapPinPickerScreenState extends State<MapPinPickerScreen> {
  final MapController _mapController = MapController();
  late final ValueNotifier<LatLng> _currentPositionNotifier;
  late final TileProvider _tileProvider;

  @override
  void initState() {
    super.initState();
    final initialPos = widget.initialPosition ?? const LatLng(19.076, 72.877); // default Mumbai
    _currentPositionNotifier = ValueNotifier<LatLng>(initialPos);
    _tileProvider = _initTileProvider();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _currentPositionNotifier.dispose();
    super.dispose();
  }

  TileProvider _initTileProvider() {
    try {
      return FMTCTileProvider(
        stores: const {
          'osmMapStore': BrowseStoreStrategy.readUpdateCreate,
        },
      );
    } catch (_) {
      return NetworkTileProvider();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pick Location on Map',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // 1. Interactive map canvas
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPositionNotifier.value,
              initialZoom: 16.0,
              minZoom: 11.0,
              maxZoom: 19.0,
              onPositionChanged: (pos, hasGesture) {
                _currentPositionNotifier.value = pos.center;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.orderkart.app',
                tileProvider: _tileProvider,
              ),
            ],
          ),

          // 2. Centered Pin overlay (stationary)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 36.0), // offset pin tip to exact center
              child: Icon(
                Icons.location_on_rounded,
                color: Colors.red[800],
                size: 40,
              ),
            ),
          ),

          // 3. Confirm card layout at bottom
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Drag the map to place the pin at the exact location.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<LatLng>(
                      valueListenable: _currentPositionNotifier,
                      builder: (context, pos, child) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Coords: ${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(context, pos);
                                },
                                child: Text(
                                  'Confirm Location',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
