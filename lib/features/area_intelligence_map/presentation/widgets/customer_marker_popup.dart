import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../customer/domain/customer.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../settings/presentation/settings_provider.dart';
import '../../../../core/database/database_helper.dart';

class CustomerMarkerPopup extends ConsumerWidget {
  final Customer customer;
  final VoidCallback onClose;

  const CustomerMarkerPopup({
    super.key,
    required this.customer,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final currency = settingsAsync.valueOrNull?.currency ?? '₹';
    return Card(
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 310,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        customer.name,
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (customer.isVip) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: const Color(0xFFF59E0B), width: 0.8),
                          ),
                          child: Text(
                            'VIP',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              customer.address.isNotEmpty
                  ? customer.address
                  : 'House #${customer.houseNumber}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: customer.outstandingBalance > 0
                    ? Colors.red.withOpacity(0.08)
                    : Colors.teal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 16,
                    color: customer.outstandingBalance > 0
                        ? Colors.red[700]
                        : Colors.teal[700],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    customer.outstandingBalance >= 0
                        ? 'Outstanding: $currency${customer.outstandingBalance.toStringAsFixed(2)}'
                        : 'Advance Credit: $currency${customer.outstandingBalance.abs().toStringAsFixed(2)}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: customer.outstandingBalance > 0
                          ? Colors.red[800]
                          : Colors.teal[800],
                    ),
                  ),
                ],
              ),
            ),
            if (customer.lastOrderDate.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.history_rounded,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Last Order: ${customer.lastOrderDate}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            // Call & WhatsApp Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.call,
                        size: 16, color: Colors.blueAccent),
                    label: const Text('Call'),
                    onPressed: () => _callNumber(customer.phone1),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon:
                        const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                    label: const Text('WhatsApp'),
                    onPressed: () => _openWhatsApp(customer.phone1, currency),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // New Order & Dispatch Worker & Navigation Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.shopping_cart_rounded, size: 16),
                    label: const Text('New Order'),
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.createOrder,
                        arguments: {'customerId': customer.id},
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Dispatch to Worker',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.amber.withOpacity(0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.share_location_rounded,
                      color: Colors.amber),
                  onPressed: () => _dispatchToWorker(currency),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'GPS Navigation',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.navigation_rounded,
                      color: Colors.blueAccent),
                  onPressed: () =>
                      _navigateToGps(customer.latitude, customer.longitude),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _callNumber(String num) async {
    if (num.isNotEmpty) {
      try {
        final db = await DatabaseHelper.instance.database;
        await db.insert('call_logs', {
          'customer_id': customer.id,
          'customer_name': customer.name,
          'phone': num,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    }
    final uri = Uri.parse('tel:$num');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone, String currency) async {
    final formatted = phone.replaceAll(RegExp(r'\D'), '');
    final duesText = customer.outstandingBalance > 0
        ? 'Pending Dues: $currency${customer.outstandingBalance.toStringAsFixed(2)}'
        : 'Credit Balance: $currency${customer.outstandingBalance.abs().toStringAsFixed(2)}';
    final addressText = customer.address.isNotEmpty
        ? customer.address
        : 'House #${customer.houseNumber}';
    final msg = Uri.encodeComponent('Hello ${customer.name}! 👋\n'
        'Regarding your delivery to $addressText:\n'
        '$duesText\n'
        'Thank you for ordering with OrderKart!');
    final uri = Uri.parse('https://wa.me/$formatted?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _dispatchToWorker(String currency) async {
    final addressText = customer.address.isNotEmpty
        ? customer.address
        : 'House #${customer.houseNumber}';
    final mapsUrl =
        'https://www.google.com/maps/search/?api=1&query=${customer.latitude},${customer.longitude}';
    final dispatchMsg = Uri.encodeComponent('🚚 *ORDERKART DELIVERY DISPATCH*\n'
        'Customer: ${customer.name}\n'
        'Phone: ${customer.phone1}\n'
        'Address: $addressText\n'
        'Dues: $currency${customer.outstandingBalance.toStringAsFixed(2)}\n'
        'Maps Location: $mapsUrl');
    final uri = Uri.parse('https://wa.me/?text=$dispatchMsg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _navigateToGps(double lat, double lng) async {
    final uri = Uri.parse('google.navigation:q=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      final webUri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    }
  }
}
