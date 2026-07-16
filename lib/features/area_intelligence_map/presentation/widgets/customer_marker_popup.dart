import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../customer/domain/customer.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../settings/presentation/settings_provider.dart';

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
        width: 300,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    customer.name,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
              customer.address.isNotEmpty ? customer.address : 'No Address Stored',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  customer.outstandingBalance >= 0
                      ? 'Outstanding: $currency${customer.outstandingBalance.toStringAsFixed(2)}'
                      : 'Advance: $currency${customer.outstandingBalance.abs().toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: customer.outstandingBalance > 500 ? Colors.red[800] : Colors.grey[800],
                  ),
                ),
              ],
            ),
            if (customer.lastOrderDate.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.history_rounded, size: 14, color: Colors.grey),
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
                    icon: const Icon(Icons.call, size: 16),
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
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                    label: const Text('WhatsApp'),
                    onPressed: () => _openWhatsApp(customer.phone1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.navigation_rounded, color: Colors.blueAccent),
                  onPressed: () => _navigateToGps(customer.latitude, customer.longitude),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _callNumber(String num) async {
    final uri = Uri.parse('tel:$num');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    // Standard quick link formatting
    final formatted = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/$formatted');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _navigateToGps(double lat, double lng) async {
    final uri = Uri.parse('google.navigation:q=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      final webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri);
      }
    }
  }
}
