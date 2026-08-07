import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../settings/presentation/settings_provider.dart';

class CashDrawerScreen extends ConsumerStatefulWidget {
  const CashDrawerScreen({super.key});

  @override
  ConsumerState<CashDrawerScreen> createState() => _CashDrawerScreenState();
}

class _CashDrawerScreenState extends ConsumerState<CashDrawerScreen> {
  final TextEditingController _openingFloatCon = TextEditingController();
  final Map<int, TextEditingController> _denominationCons = {
    500: TextEditingController(),
    200: TextEditingController(),
    100: TextEditingController(),
    50: TextEditingController(),
    20: TextEditingController(),
    10: TextEditingController(),
    5: TextEditingController(),
    1: TextEditingController(), // Coins
  };

  double _openingFloat = 1000.0;
  double _cashInflow = 0.0;
  double _cashOutflow = 0.0;
  int _cashInflowTxCount = 0;
  int _cashOutflowTxCount = 0;
  bool _loading = true;
  bool _useDenominations = true;
  final TextEditingController _manualCountCon = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDrawerData();
  }

  @override
  void dispose() {
    _openingFloatCon.dispose();
    _manualCountCon.dispose();
    for (final c in _denominationCons.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadDrawerData() async {
    setState(() => _loading = true);
    final settings = ref.read(settingsProvider).valueOrNull;
    _openingFloat = settings?.cashDrawerOpeningFloat ?? 1000.0;
    _openingFloatCon.text = _openingFloat.toStringAsFixed(0);

    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // 1. Calculate today's cash payments collected
    final cashPayments = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0.0) as total, COUNT(*) as count
      FROM payments
      WHERE method = 'cash' AND DATE(created_at) = DATE(?)
    ''', [todayStr]);

    // 2. Calculate today's cash expenses paid
    final cashExpenses = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0.0) as total, COUNT(*) as count
      FROM expenses
      WHERE (payment_method = 'cash' OR payment_method IS NULL OR payment_method = '')
        AND DATE(date) = DATE(?)
    ''', [todayStr]);

    setState(() {
      _cashInflow =
          (cashPayments.first['total'] as num?)?.toDouble() ?? 0.0;
      _cashInflowTxCount =
          (cashPayments.first['count'] as num?)?.toInt() ?? 0;

      _cashOutflow =
          (cashExpenses.first['total'] as num?)?.toDouble() ?? 0.0;
      _cashOutflowTxCount =
          (cashExpenses.first['count'] as num?)?.toInt() ?? 0;

      _loading = false;
    });
  }

  double get _physicalCountTotal {
    if (!_useDenominations) {
      return double.tryParse(_manualCountCon.text) ?? 0.0;
    }
    double total = 0.0;
    _denominationCons.forEach((denom, controller) {
      final count = int.tryParse(controller.text) ?? 0;
      total += denom * count;
    });
    return total;
  }

  double get _expectedCash {
    return _openingFloat + _cashInflow - _cashOutflow;
  }

  double get _discrepancy {
    return _physicalCountTotal - _expectedCash;
  }

  void _shareReport(String currency) {
    final now = DateTime.now();
    final dateFormatted = AppFormatters.dateTime(now);
    final disc = _discrepancy;
    final discLabel = disc == 0
        ? '✅ EXACT MATCH (₹0.00)'
        : (disc > 0
            ? '🔵 CASH OVER (+ $currency${disc.abs().toStringAsFixed(2)})'
            : '🔴 CASH SHORT (- $currency${disc.abs().toStringAsFixed(2)})');

    final text = '''
🏦 *DAILY CASH REGISTER RECONCILIATION*
📅 Date: $dateFormatted
🏢 Business: ${ref.read(settingsProvider).valueOrNull?.businessName ?? 'OrderKart'}
------------------------------------
💵 Opening Float: $currency${_openingFloat.toStringAsFixed(2)}
📥 Cash Inflow ($_cashInflowTxCount orders): + $currency${_cashInflow.toStringAsFixed(2)}
📤 Cash Expenses ($_cashOutflowTxCount entries): - $currency${_cashOutflow.toStringAsFixed(2)}
------------------------------------
📊 *Expected Cash in Bag: $currency${_expectedCash.toStringAsFixed(2)}*
✋ *Physical Cash Counted: $currency${_physicalCountTotal.toStringAsFixed(2)}*
⚖️ *Status: $discLabel*
------------------------------------
Generated via OrderKart POS Drawer
''';

    Clipboard.setData(ClipboardData(text: text));
    SnackbarHelper.showSuccess(context, 'Reconciliation report copied to clipboard');
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).valueOrNull;
    final currency = settings?.currency ?? '₹';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppScaffold(
      title: 'Daily Cash Register',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'Refresh Totals',
          onPressed: _loadDrawerData,
        ),
        IconButton(
          icon: const Icon(Icons.share_rounded),
          tooltip: 'Share Reconciliation',
          onPressed: () => _shareReport(currency),
        ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Top Reconciliation Balance Card
                  _buildReconciliationCard(currency, isDark),
                  const SizedBox(height: 16),

                  // 2. Breakdown Cards Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          title: 'Cash Inflow',
                          amount: _cashInflow,
                          count: '$_cashInflowTxCount orders',
                          color: AppColors.success,
                          icon: Icons.arrow_downward_rounded,
                          currency: currency,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricTile(
                          title: 'Cash Outflow',
                          amount: _cashOutflow,
                          count: '$_cashOutflowTxCount expenses',
                          color: AppColors.error,
                          icon: Icons.arrow_upward_rounded,
                          currency: currency,
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3. Opening Float Card
                  _buildOpeningFloatCard(currency, isDark),
                  const SizedBox(height: 16),

                  // 4. Physical Cash Count Form (Denominations)
                  _buildPhysicalCountSection(currency, isDark),
                  const SizedBox(height: 24),

                  // 5. Close Register Action Button
                  ElevatedButton.icon(
                    onPressed: () => _shareReport(currency),
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text(
                      'Export & Close Daily Register',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildReconciliationCard(String currency, bool isDark) {
    final disc = _discrepancy;
    final isExact = disc == 0;
    final isOver = disc > 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isExact
              ? [const Color(0xFF0F766E), const Color(0xFF14B8A6)]
              : (isOver
                  ? [const Color(0xFF1E40AF), const Color(0xFF3B82F6)]
                  : [const Color(0xFF991B1B), const Color(0xFFEF4444)]),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isExact
                    ? const Color(0xFF14B8A6)
                    : (isOver ? const Color(0xFF3B82F6) : const Color(0xFFEF4444)))
                .withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'EXPECTED CASH IN DRAWER',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isExact
                      ? '✅ EXACT MATCH'
                      : (isOver ? '🔵 OVER +$currency${disc.toStringAsFixed(0)}' : '🔴 SHORT -$currency${disc.abs().toStringAsFixed(0)}'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$currency${_expectedCash.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Divider(color: Colors.white24, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Counted: $currency${_physicalCountTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Float: $currency${_openingFloat.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required double amount,
    required String count,
    required Color color,
    required IconData icon,
    required String currency,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$currency${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            count,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildOpeningFloatCard(String currency, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_clock_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Opening Cash Float',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  'Morning cash starting balance in bag',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 90,
            child: TextField(
              controller: _openingFloatCon,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                prefixText: '$currency ',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onChanged: (v) {
                setState(() {
                  _openingFloat = double.tryParse(v) ?? 0.0;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhysicalCountSection(String currency, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PHYSICAL CASH COUNT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gray500,
                  letterSpacing: 0.8,
                ),
              ),
              Row(
                children: [
                  Text(
                    _useDenominations ? 'Denominations' : 'Total Direct',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 4),
                  Switch(
                    value: _useDenominations,
                    onChanged: (v) => setState(() => _useDenominations = v),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_useDenominations)
            TextField(
              controller: _manualCountCon,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Total Counted Cash Amount',
                prefixText: '$currency ',
                prefixIcon: const Icon(Icons.payments_rounded),
              ),
              onChanged: (_) => setState(() {}),
            )
          else ...[
            const Text(
              'Count note quantities by denomination:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            ..._denominationCons.entries.map((e) {
              final denom = e.key;
              final controller = e.value;
              final count = int.tryParse(controller.text) ?? 0;
              final subtotal = denom * count;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 70,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: denom >= 100
                            ? Colors.blue.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        denom == 1 ? 'Coins' : '$currency$denom',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: denom >= 100 ? Colors.blue.shade700 : Colors.orange.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('×', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          hintText: '0',
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 90,
                      child: Text(
                        '= $currency${subtotal.toStringAsFixed(0)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
