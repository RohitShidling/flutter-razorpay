import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/utils/money_format.dart';

/// Toggle + breakdown for applying wallet balance at checkout.
class WalletCheckoutSection extends StatelessWidget {
  final bool useWallet;
  final ValueChanged<bool> onUseWalletChanged;
  final String? walletBalance;
  final double? walletApplied;
  final double? gatewayAmount;
  final double? totalAmount;
  final bool loadingPreview;

  const WalletCheckoutSection({
    super.key,
    required this.useWallet,
    required this.onUseWalletChanged,
    this.walletBalance,
    this.walletApplied,
    this.gatewayAmount,
    this.totalAmount,
    this.loadingPreview = false,
  });

  bool get _hasBalance {
    final raw = walletBalance ?? '';
    final n = double.tryParse(raw.replaceAll(',', '')) ?? 0;
    return n > 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!_hasBalance) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.money_dollar_circle_fill, color: AppTheme.primaryColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Use wallet balance', style: TextStyle(fontWeight: FontWeight.w800)),
                    Text(
                      'Available: ₹${MoneyFormat.display(walletBalance)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              CupertinoSwitch(
                value: useWallet,
                activeTrackColor: AppTheme.primaryColor,
                onChanged: onUseWalletChanged,
              ),
            ],
          ),
          if (loadingPreview)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: CupertinoActivityIndicator(radius: 10),
            )
          else if (useWallet && walletApplied != null && totalAmount != null) ...[
            const SizedBox(height: 10),
            if (walletApplied! > 0)
              Text(
                'Wallet: −₹${MoneyFormat.display(walletApplied)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade700,
                ),
              ),
            if ((gatewayAmount ?? 0) > 0)
              Text(
                'Pay via Razorpay: ₹${MoneyFormat.display(gatewayAmount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : AppTheme.textPrimaryLight,
                ),
              )
            else
              Text(
                'Fully covered by wallet — no gateway step',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.green.shade700,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
