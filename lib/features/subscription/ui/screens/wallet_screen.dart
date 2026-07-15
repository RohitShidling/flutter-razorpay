import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/providers/payment_provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/utils/money_format.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pay = context.read<PaymentProvider>();
      Future.wait([
        pay.fetchWallet(),
        pay.fetchWalletTransactions(),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pay = context.watch<PaymentProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final balance = pay.walletBalance ?? '0.00';
    final txs = pay.walletTransactions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wallet', style: TextStyle(fontWeight: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              pay.fetchWallet(),
              pay.fetchWalletTransactions(),
            ]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withValues(alpha: 0.75),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Available balance',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${MoneyFormat.display(balance)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Credits from downsizing your meal pack appear here.',
                    style: TextStyle(color: Colors.white70, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Wallet activity',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppTheme.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 12),
            if (pay.isLoading && txs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CupertinoActivityIndicator()),
              )
            else if (txs.isEmpty)
              Text(
                'No wallet activity yet. When you move to a smaller meal pack, the credit will show here.',
                style: TextStyle(
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                ),
              )
            else
              ...txs.map((raw) {
                if (raw is! Map) return const SizedBox.shrink();
                final tx = Map<String, dynamic>.from(raw);
                final direction = (tx['direction'] ?? '').toString().toLowerCase();
                final isCredit = direction == 'credit';
                final amount = MoneyFormat.display(tx['amount']);
                final whenRaw = (tx['created_at'] ?? '').toString();
                String when = '';
                if (whenRaw.isNotEmpty) {
                  final parsedDt = DateTime.tryParse(whenRaw);
                  if (parsedDt != null) {
                    when = DateFormat('d MMM yyyy, h:mm a').format(parsedDt.toLocal());
                  } else {
                    when = whenRaw;
                  }
                }
                // Strip internal order IDs (e.g. "ORD-123" or "Order ID: ...") from user-facing description
                final rawDesc = (tx['description'] ?? 'Wallet credit').toString();
                final desc = rawDesc.replaceAll(RegExp(r'\s*\(?(?:ORD-|Order\s*ID:?|Order\s*#)[^\)\s]+\)?', caseSensitive: false), '').trim();

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: (isCredit ? Colors.green : Colors.orange)
                          .withValues(alpha: 0.12),
                      child: Icon(
                        isCredit ? CupertinoIcons.plus : CupertinoIcons.minus,
                        color: isCredit ? Colors.green : Colors.orange,
                      ),
                    ),
                    title: Text(desc, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: when.isNotEmpty ? Text(when) : null,
                    trailing: Text(
                      '${isCredit ? '+' : '-'}₹$amount',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: isCredit ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
        ),
      ),
    );
  }
}
