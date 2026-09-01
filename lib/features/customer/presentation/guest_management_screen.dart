import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_scaffold.dart';

import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/custom_search_bar.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_shimmer.dart';
import '../../../core/utils/formatters.dart';
import '../domain/customer.dart';
import 'customer_provider.dart';
import '../../area/presentation/area_provider.dart';
import '../../../core/services/customer_order_sync_service.dart';

class GuestManagementScreen extends ConsumerStatefulWidget {
  const GuestManagementScreen({super.key});

  @override
  ConsumerState<GuestManagementScreen> createState() => _GuestManagementScreenState();
}

class _GuestManagementScreenState extends ConsumerState<GuestManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedLoginFilter = 'All';


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('tel:');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('https://wa.me/91');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _showConvertModal(BuildContext context, Customer customer) async {
    final codeController = TextEditingController();
    String? selectedAreaId;
    String? selectedStreetId;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              left: 16,
              right: 16,
              top: 20,
            ),
            child: GlassContainer(
              borderRadius: BorderRadius.circular(24),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Convert to Registered Customer',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              customer.name.isNotEmpty ? customer.name : customer.phone1,
                              style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  TextField(
                    controller: codeController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Customer Code (e.g. OK1025)',
                      hintText: 'Enter unique code',
                      prefixIcon: const Icon(Icons.badge_rounded, color: AppColors.primary),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Consumer(
                    builder: (context, ref, _) {
                      final areasAsync = ref.watch(areaProvider);
                      return areasAsync.when(
                        loading: () => const Center(child: LinearProgressIndicator()),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (areas) => DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Assign Delivery Area (Optional)',
                            prefixIcon: const Icon(Icons.location_on_rounded, color: AppColors.primary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          value: selectedAreaId,
                          items: areas.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                          onChanged: (val) {
                            setModalState(() {
                              selectedAreaId = val;
                              selectedStreetId = null;
                            });
                          },
                        ),
                      );
                    },
                  ),
                  if (selectedAreaId != null) ...[
                    const SizedBox(height: 12),
                    Consumer(
                      builder: (context, ref, _) {
                        return ref.watch(areaDescendantLocationsProvider(selectedAreaId!)).when(
                              loading: () => const Center(child: LinearProgressIndicator()),
                              error: (_, __) => const SizedBox.shrink(),
                              data: (streets) => DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  labelText: 'Assign Road / Street',
                                  prefixIcon: const Icon(Icons.alt_route_rounded, color: AppColors.primary),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                value: selectedStreetId,
                                items: streets.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                                onChanged: (val) => setModalState(() => selectedStreetId = val),
                              ),
                            );
                      },
                    ),
                  ],
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Save & Convert Customer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final code = codeController.text.trim();
                      if (code.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid customer code.')),
                        );
                        return;
                      }

                      final success = await ref.read(guestCustomersProvider.notifier).convertGuest(
                            customerId: customer.id,
                            newCustomerCode: code,
                            streetId: selectedStreetId ?? selectedAreaId,
                          );

                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Customer converted successfully with code !' : 'Failed to convert customer.'),
                            backgroundColor: success ? const Color(0xFF10B981) : Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final guestState = ref.watch(guestCustomersProvider);
    final loginLogsState = ref.watch(customerLoginLogsProvider);

    return AppScaffold(
      title: 'Guest Customers & Logins',
      actions: [
        IconButton(
          icon: const Icon(Icons.sync_rounded),
          tooltip: 'Sync with Server',
          onPressed: () async {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Syncing guest customers and login logs...'), duration: Duration(seconds: 1)),
            );
            await CustomerOrderSyncService.instance.pullRemoteCustomersAndGuests();
            await CustomerOrderSyncService.instance.pullLoginLogs();
            ref.read(guestCustomersProvider.notifier).load();
            ref.read(customerLoginLogsProvider.notifier).load();
          },
        ),
      ],
      body: Column(
        children: [
          // ── Tab Bar ───────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.primary,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(
                  icon: Icon(Icons.person_pin_circle_rounded, size: 20),
                  text: 'Guest Customers',
                ),
                Tab(
                  icon: Icon(Icons.history_rounded, size: 20),
                  text: 'Login Activity',
                ),
              ],
            ),
          ),

          // ── Tab Content ───────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: GUEST CUSTOMERS
                _buildGuestsTab(guestState, isDark),

                // TAB 2: LOGIN AUDIT LOGS
                _buildLoginLogsTab(loginLogsState, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestsTab(AsyncValue<List<Customer>> guestState, bool isDark) {
    return Column(
      children: [
        CustomSearchBar(
          hint: 'Search guests by name, phone, address...',
          onChanged: (q) => ref.read(guestCustomersProvider.notifier).search(q),
        ),

        Expanded(
          child: guestState.when(
            loading: () => const LoadingShimmer(),
            error: (err, _) => Center(child: Text('Error loading guests: ')),
            data: (guests) {
              if (guests.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.person_off_rounded,
                  title: 'No Guest Customers Found',
                  subtitle: 'When customers log in as Guest on the mobile app, they will appear here.',
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  await CustomerOrderSyncService.instance.pullRemoteCustomersAndGuests();
                  ref.read(guestCustomersProvider.notifier).load();
                },
                child: ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 96, top: 4),
                  itemCount: guests.length,
                  itemBuilder: (ctx, i) {
                    final guest = guests[i];
                    return _buildGuestCard(guest, isDark);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGuestCard(Customer guest, bool isDark) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06)),
      ),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.amber.withOpacity(0.15),
                  child: Text(
                    guest.name.isNotEmpty ? guest.name.substring(0, 1).toUpperCase() : 'G',
                    style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              guest.name.isNotEmpty ? guest.name : 'Guest User',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.withOpacity(0.4)),
                            ),
                            child: const Text(
                              'GUEST',
                              style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        guest.phone1.isNotEmpty ? guest.phone1 : 'No phone number',
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.phone_rounded, color: Colors.blueAccent, size: 20),
                  onPressed: () => _makePhoneCall(guest.phone1),
                ),
                IconButton(
                  icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 20),
                  onPressed: () => _openWhatsApp(guest.phone1),
                ),
              ],
            ),
            if (guest.address.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: isDark ? Colors.white38 : Colors.black38),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      guest.address,
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Orders:  • Total: ₹',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white60 : Colors.black54),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                  label: const Text('Convert to Customer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () => _showConvertModal(context, guest),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginLogsTab(AsyncValue<List<Map<String, dynamic>>> loginLogsState, bool isDark) {
    final filters = ['All', 'Guest', 'Phone + Password', 'Code + Password', 'Password Setup', 'Registration'];

    return Column(
      children: [
        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: filters.map((f) {
              final isSelected = _selectedLoginFilter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withOpacity(0.15),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.primary : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (_) {
                    setState(() => _selectedLoginFilter = f);
                    ref.read(customerLoginLogsProvider.notifier).filterByMethod(f == 'All' ? null : f);
                  },
                ),
              );
            }).toList(),
          ),
        ),

        // Logs List
        Expanded(
          child: loginLogsState.when(
            loading: () => const LoadingShimmer(),
            error: (err, _) => Center(child: Text('Error loading login logs: ')),
            data: (logs) {
              if (logs.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.history_toggle_off_rounded,
                  title: 'No Recent Login Logs',
                  subtitle: 'Login activity from the Customer app will be tracked here for 5 days.',
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  await CustomerOrderSyncService.instance.pullLoginLogs();
                  ref.read(customerLoginLogsProvider.notifier).load();
                },
                child: ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 96, top: 4),
                  itemCount: logs.length,
                  itemBuilder: (ctx, i) {
                    final log = logs[i];
                    return _buildLoginLogCard(log, isDark);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoginLogCard(Map<String, dynamic> log, bool isDark) {
    final name = (log['customer_name']?.toString() ?? 'Guest').trim();
    final phone = (log['customer_phone']?.toString() ?? '').trim();
    final method = (log['login_method']?.toString() ?? 'Login').trim();
    final device = (log['device_info']?.toString() ?? 'Android').trim();
    final loggedInAtStr = log['logged_in_at']?.toString() ?? '';
    final code = (log['customer_code']?.toString() ?? '').trim();

    DateTime? loggedInAt = DateTime.tryParse(loggedInAtStr);
    String timeDisplay = loggedInAt != null ? AppFormatters.dateTime(loggedInAt) : loggedInAtStr;


    final isGuest = method.toLowerCase().contains('guest') || code.isEmpty;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05)),
      ),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: isGuest ? Colors.amber.withOpacity(0.15) : AppColors.primary.withOpacity(0.12),
          child: Icon(
            isGuest ? Icons.person_pin_circle_rounded : Icons.verified_user_rounded,
            color: isGuest ? Colors.amber : AppColors.primary,
            size: 20,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name.isNotEmpty ? name : (phone.isNotEmpty ? phone : 'Guest User'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isGuest ? Colors.amber.withOpacity(0.15) : AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                method,
                style: TextStyle(
                  color: isGuest ? Colors.amber[800] : AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                if (phone.isNotEmpty) ...[
                  Text(phone, style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                  const SizedBox(width: 8),
                ],
                if (code.isNotEmpty) ...[
                  Text('• Code: $code', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(width: 8),
                ],
                Text('• $device', style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38)),
              ],
            ),

            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  timeDisplay,
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.black38),
                ),
                const Text(
                  'Auto-expires in 5 days',
                  style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
