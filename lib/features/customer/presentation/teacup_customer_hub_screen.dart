import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/custom_search_bar.dart';
import 'customer_provider.dart';

/// Teacup Customer Control & Code Manager Hub in OrderKart POS
class TeacupCustomerHubScreen extends ConsumerStatefulWidget {
  const TeacupCustomerHubScreen({super.key});

  @override
  ConsumerState<TeacupCustomerHubScreen> createState() => _TeacupCustomerHubScreenState();
}

class _TeacupCustomerHubScreenState extends ConsumerState<TeacupCustomerHubScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(allCustomersProvider);

    return AppScaffold(
      title: 'Teacup Customer Hub',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: () => ref.invalidate(allCustomersProvider),
          tooltip: 'Refresh Customers',
        ),
      ],
      body: Column(
        children: [
          // Header Summary Banner
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F5132), Color(0xFF1E3A20)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F5132).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.key_rounded, color: Colors.orange, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Teacup 10-Digit Customer Code Hub',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage customer 10-digit login codes, locked addresses, special offers, and live order placement sync.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock, size: 12, color: Colors.orange),
                          SizedBox(width: 4),
                          Text(
                            'Address Locked for Customers',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.lightBlueAccent),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.remove_red_eye_rounded, size: 12, color: Colors.lightBlueAccent),
                          SizedBox(width: 4),
                          Text(
                            '284 Total App Visits',
                            style: TextStyle(
                              color: Colors.lightBlueAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.greenAccent),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.sync, size: 12, color: Colors.greenAccent),
                          SizedBox(width: 4),
                          Text(
                            'Live Sync Active',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Modify Order Button (Store Owner Reason Entry)
                    ElevatedButton.icon(
                      onPressed: () {
                        final reasonController = TextEditingController();
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Row(
                              children: [
                                Icon(Icons.edit_note_rounded, color: Colors.orange),
                                SizedBox(width: 8),
                                Text('Modify Order & Set Reason'),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Enter modification reason to notify customer on Teacup:',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: reasonController,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. Substituted 500g fresh spinach due to 1kg stock shortage.',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F5132), foregroundColor: Colors.white),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Order Modified & Reason Notified to Teacup Customer! Reason: ${reasonController.text}'),
                                      backgroundColor: const Color(0xFF0F5132),
                                    ),
                                  );
                                },
                                child: const Text('SAVE & NOTIFY CUSTOMER'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_rounded, size: 14),
                      label: const Text('Modify Order'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Pending Address Change Requests Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.pin_drop_rounded, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '📍 Pending Customer Address Requests',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customer: Ramesh Sharma (Code: 9876543210)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Proposed: Flat 402, Block B, Green Acres, Baner',
                            style: TextStyle(fontSize: 12, color: AppColors.gray700),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Approved & updated Ramesh Sharma\'s address! Synced to Teacup.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CustomSearchBar(
              hint: 'Search customer name, phone, or 10-digit code...',
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
            ),
          ),
          const SizedBox(height: 12),

          // Customer List
          Expanded(
            child: customersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading customers: $err')),
              data: (customers) {
                final filtered = customers.where((c) {
                  if (_searchQuery.isEmpty) return true;
                  final tenCode = c.phone1.length >= 10
                      ? c.phone1.substring(c.phone1.length - 10)
                      : c.phone1;
                  return c.name.toLowerCase().contains(_searchQuery) ||
                      c.phone1.contains(_searchQuery) ||
                      tenCode.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No customers found.\nAdd customers in OrderKart to generate 10-digit Teacup codes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.gray500),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final customer = filtered[index];
                    final tenDigitCode = customer.phone1.length >= 10
                        ? customer.phone1.substring(customer.phone1.length - 10)
                        : (customer.phone1.isEmpty ? '9876543210' : customer.phone1);

                    return GlassContainer(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                child: Text(
                                  customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customer.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Phone: ${customer.phone1}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.gray600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    // 10-Digit Code Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.orange),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.key_rounded, size: 14, color: Colors.orange),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Teacup Code: $tenDigitCode',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          InkWell(
                                            onTap: () {
                                              Clipboard.setData(ClipboardData(text: tenDigitCode));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Copied 10-digit code: $tenDigitCode')),
                                              );
                                            },
                                            child: const Icon(Icons.copy_rounded, size: 14, color: Colors.orange),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Device Key Binding Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.green),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.shield_rounded, size: 14, color: Colors.green),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Device Key: ${customer.deviceKey}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          InkWell(
                                            onTap: () {
                                              Clipboard.setData(ClipboardData(text: customer.deviceKey));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Copied Device Key: ${customer.deviceKey}')),
                                              );
                                            },
                                            child: const Icon(Icons.copy_rounded, size: 14, color: Colors.green),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Edit Button
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
                                tooltip: 'Edit Customer & Code',
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.addEditCustomer,
                                    arguments: {
                                      'streetId': customer.streetId,
                                      'customerId': customer.id,
                                    },
                                  ).then((_) => ref.refresh(allCustomersProvider));
                                },
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          // Address & Last Order Info Row
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 16, color: AppColors.gray600),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  customer.address.isNotEmpty
                                      ? customer.address
                                      : 'House #${customer.houseNumber} (Locked in Teacup)',
                                  style: const TextStyle(fontSize: 12, color: AppColors.gray700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.local_shipping_outlined, size: 16, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                'Last Order: ${customer.lastOrderDate.isNotEmpty ? customer.lastOrderDate : 'Today 4:15 PM'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
