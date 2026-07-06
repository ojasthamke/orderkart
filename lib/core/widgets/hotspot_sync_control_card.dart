import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../constants/app_colors.dart';
import '../utils/haptics.dart';
import '../services/hotspot_sync_service.dart';
import 'snackbar_helper.dart';

class HotspotSyncControlCard extends StatefulWidget {
  final String workerId;
  final String workerName;
  final VoidCallback onSyncCompleted;

  const HotspotSyncControlCard({
    super.key,
    required this.workerId,
    required this.workerName,
    required this.onSyncCompleted,
  });

  @override
  State<HotspotSyncControlCard> createState() => _HotspotSyncControlCardState();
}

class _HotspotSyncControlCardState extends State<HotspotSyncControlCard> {
  // granular modules selections
  final Map<String, bool> _modules = {
    'areas_streets': true,
    'customers': true,
    'orders_payments': true,
    'products': true,
    'expenses': true,
    'photos': true,
  };

  bool _loading = false;
  String _status = 'Disconnected';
  String? _localIp;

  @override
  void initState() {
    super.initState();
    _fetchNetworkInfo();
  }

  Future<void> _fetchNetworkInfo() async {
    try {
      final info = NetworkInfo();
      final ip = await info.getWifiIP();
      if (mounted) {
        setState(() {
          _localIp = ip;
        });
      }
    } catch (_) {}
  }

  List<String> _getSelectedModulesList() {
    return _modules.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool isServer = HotspotSyncService.isServerRunning;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gray200),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isServer ? AppColors.successSurface : AppColors.primarySurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.wifi_tethering_rounded,
                  color: isServer ? AppColors.success : AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'P2P Hotspot Sync Control',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                    Text(
                      _localIp != null ? 'My IP: $_localIp' : 'Connect to a hotspot to start',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              // Server Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isServer ? AppColors.successSurface : AppColors.gray100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isServer ? 'RECEIVING ON' : 'RECEIVER OFF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: isServer ? AppColors.success : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Selection checkboxes title
          const Text(
            'Select data modules to sync:',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),

          // Checkboxes Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 3.2,
            mainAxisSpacing: 4,
            crossAxisSpacing: 8,
            children: [
              _buildCheckbox('Areas & Streets', 'areas_streets', Icons.map_rounded),
              _buildCheckbox('Customer Info & VIP', 'customers', Icons.people_rounded),
              _buildCheckbox('Orders & Payments', 'orders_payments', Icons.receipt_rounded),
              _buildCheckbox('Products Catalog', 'products', Icons.inventory_2_rounded),
              _buildCheckbox('Expenses Log', 'expenses', Icons.payments_rounded),
              _buildCheckbox('Customer Photos', 'photos', Icons.photo_library_rounded),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Status log box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.gray200),
            ),
            child: Row(
              children: [
                _loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    : Icon(
                        isServer ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        size: 14,
                        color: isServer ? AppColors.success : AppColors.textHint,
                      ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _status,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bidirectional Action Buttons
          Row(
            children: [
              // Button 1: Receiver Server Toggle
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _toggleReceiverServer,
                  icon: Icon(isServer ? Icons.stop_rounded : Icons.play_arrow_rounded),
                  label: Text(isServer ? 'Stop Receiver' : 'Start Receiver', style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isServer ? AppColors.error : AppColors.primary,
                    side: BorderSide(color: isServer ? AppColors.error : AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Button 2: Send Client P2P
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _sendSyncPacket,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Send / Sync Now', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckbox(String label, String key, IconData icon) {
    final bool isSelected = _modules[key] ?? false;
    return InkWell(
      onTap: () {
        AppHaptics.lightImpact();
        setState(() {
          _modules[key] = !isSelected;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: isSelected,
            activeColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: (val) {
              AppHaptics.lightImpact();
              setState(() {
                _modules[key] = val ?? false;
              });
            },
          ),
          Icon(icon, size: 16, color: isSelected ? AppColors.primary : AppColors.gray400),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleReceiverServer() async {
    AppHaptics.buttonClick();
    final bool isRunning = HotspotSyncService.isServerRunning;

    setState(() => _loading = true);

    try {
      if (isRunning) {
        await HotspotSyncService.stopServer();
        setState(() {
          _status = 'Sync receiver stopped.';
        });
      } else {
        await _fetchNetworkInfo();
        await HotspotSyncService.startServer(
          onStatusUpdate: (msg) {
            if (mounted) setState(() => _status = msg);
          },
          onSyncSuccess: () {
            if (mounted) {
              SnackbarHelper.showSuccess(context, '✅ Data packet successfully received and merged!');
              widget.onSyncCompleted();
              setState(() {
                _status = 'Last sync completed successfully at ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}';
              });
            }
          },
        );
        setState(() {
          _status = 'Receiver started. Waiting for connection...';
        });
      }
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendSyncPacket() async {
    AppHaptics.buttonClick();
    final selected = _getSelectedModulesList();
    if (selected.isEmpty) {
      SnackbarHelper.showError(context, '❌ Please select at least one module to send!');
      return;
    }

    setState(() {
      _loading = true;
      _status = 'Scanning subnet to discover receiver device...';
    });

    try {
      final receiverIp = await HotspotSyncService.discoverReceiverDevice();
      if (receiverIp == null || receiverIp.isEmpty) {
        if (mounted) {
          setState(() {
            _status = 'No active receiver found. Connect to hotspot/Wi-Fi and check if receiver is ON.';
          });
          SnackbarHelper.showError(context, '❌ No receiver found on the network. Check connection.');
        }
        return;
      }

      if (mounted) {
        setState(() {
          _status = 'Receiver discovered at $receiverIp. Packing and sending data...';
        });
      }

      final success = await HotspotSyncService.syncWithGateway(
        gatewayIp: receiverIp,
        workerId: widget.workerId,
        workerName: widget.workerName,
        modules: selected,
      );

      if (mounted) {
        if (success) {
          setState(() {
            _status = 'Sync sent successfully to $receiverIp!';
          });
          SnackbarHelper.showSuccess(context, '✅ Sync packet successfully sent to receiver!');
          widget.onSyncCompleted();
        } else {
          setState(() {
            _status = 'Upload failed. Receiver returned error.';
          });
          SnackbarHelper.showError(context, '❌ Sync upload failed.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = 'Sync error: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
