import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../../core/utils/haptics.dart';
import '../domain/customer.dart';
import 'customer_provider.dart';

class CallLogsScreen extends ConsumerStatefulWidget {
  const CallLogsScreen({super.key});

  @override
  ConsumerState<CallLogsScreen> createState() => _CallLogsScreenState();
}

class _CallLogsScreenState extends ConsumerState<CallLogsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _callLogs = [];
  bool _loadingLogs = true;
  String _searchQuery = '';

  final _directorySearchCon = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLogs();
  }

  @override
  void dispose() {
    _directorySearchCon.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _loadingLogs = true);
    try {
      final logs = await DatabaseHelper.instance.getCallLogs();
      if (mounted) {
        setState(() {
          _callLogs = logs;
          _loadingLogs = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLogs = false);
    }
  }

  Future<void> _placeCall(String customerId, String name, String phone) async {
    AppHaptics.buttonClick();
    
    // Copy name to clipboard
    await Clipboard.setData(ClipboardData(text: name));
    
    // Log the call in SQLite
    await DatabaseHelper.instance.insertCallLog(
      customerId: customerId,
      customerName: name,
      phone: phone,
    );

    // Open native dialer
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final telUri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    } else {
      if (mounted) SnackbarHelper.showError(context, 'Could not open phone app');
    }

    _loadLogs(); // Refresh log list
  }

  Future<void> _clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Call Logs?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to clear your local call history? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.clearCallLogs();
      _loadLogs();
      if (mounted) SnackbarHelper.showSuccess(context, 'Call logs cleared');
    }
  }

  @override
  Widget build(BuildContext context) {
    final allCustomersAsync = ref.watch(allCustomersProvider);

    return AppScaffold(
      title: 'Call Center',
      showBack: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_sweep_rounded),
          tooltip: 'Clear History',
          onPressed: _clearLogs,
        ),
      ],
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: Colors.transparent,
            indicator: AppColors.tabDecoration(context),
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            tabs: const [
              Tab(text: 'Recent Calls', icon: Icon(Icons.history_rounded)),
              Tab(text: 'Directory (Contacts)', icon: Icon(Icons.contacts_rounded)),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Recent Calls
                _buildRecentTab(),

                // Tab 2: Directory (Contacts)
                _buildDirectoryTab(allCustomersAsync),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTab() {
    if (_loadingLogs) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_callLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_missed_rounded, size: 72, color: AppColors.gray300),
            const SizedBox(height: 16),
            Text(
              'No Call History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Calls placed from this app will show up here.',
              style: TextStyle(fontSize: 12, color: AppColors.textHint),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _callLogs.length,
      itemBuilder: (context, index) {
        final log = _callLogs[index];
        final name = log['customer_name']?.toString() ?? 'Unknown';
        final phone = log['phone']?.toString() ?? '';
        final calledAt = log['called_at']?.toString() ?? '';
        final custId = log['customer_id']?.toString() ?? '';

        String dateStr = '';
        try {
          final parsed = DateTime.parse(calledAt);
          dateStr = '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
        } catch (_) {}

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.gray200),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primarySurface,
              foregroundColor: AppColors.primary,
              child: const Icon(Icons.call_made_rounded, size: 20),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(phone, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                Text(dateStr, style: const TextStyle(color: AppColors.textHint, fontSize: 11)),
              ],
            ),
            trailing: IconButton.filledTonal(
              icon: const Icon(Icons.phone_rounded, color: AppColors.primary, size: 18),
              onPressed: () => _placeCall(custId, name, phone),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDirectoryTab(AsyncValue<List<Customer>> customersAsync) {
    return customersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(child: Text('Failed to load contacts: $e')),
      data: (customers) {
        final filtered = customers.where((c) {
          final query = _searchQuery.toLowerCase();
          return c.name.toLowerCase().contains(query) ||
              c.phone1.contains(query) ||
              c.phone2.contains(query);
        }).toList();

        return Column(
          children: [
             Padding(
               padding: const EdgeInsets.all(16),
               child: TextField(
                 controller: _directorySearchCon,
                 onChanged: (val) => setState(() => _searchQuery = val),
                 decoration: InputDecoration(
                   hintText: 'Search contacts...',
                   prefixIcon: const Icon(Icons.search_rounded),
                   suffixIcon: _searchQuery.isNotEmpty
                       ? IconButton(
                           icon: const Icon(Icons.clear_rounded),
                           onPressed: () {
                             _directorySearchCon.clear();
                             setState(() => _searchQuery = '');
                           },
                         )
                       : null,
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                   contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                 ),
               ),
             ),

            // Customer List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No contacts found',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final customer = filtered[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: AppColors.gray200),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.gray100,
                              foregroundColor: AppColors.textPrimary,
                              child: Text(
                                customer.name.isNotEmpty ? customer.name.substring(0, 1).toUpperCase() : '?',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                            subtitle: Text(customer.phone1, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (customer.phone2.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.phone_callback_rounded, color: Colors.blue, size: 20),
                                    onPressed: () => _placeCall(customer.id, customer.name, customer.phone2),
                                  ),
                                IconButton.filledTonal(
                                  icon: const Icon(Icons.phone_rounded, color: AppColors.primary, size: 18),
                                  onPressed: () => _placeCall(customer.id, customer.name, customer.phone1),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
