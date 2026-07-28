import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';

import 'package:meal_app/core/network/api_endpoints.dart';

import 'package:meal_app/core/providers/payment_provider.dart';

import 'package:meal_app/core/theme/app_theme.dart';

import 'package:meal_app/core/utils/error_handler.dart';

import 'package:meal_app/core/utils/money_format.dart';
import 'package:meal_app/core/utils/upgrade_payment_history.dart';
import 'package:meal_app/features/subscription/ui/screens/payment_status_screen.dart';
import 'package:meal_app/features/subscription/ui/screens/wallet_screen.dart';
import 'package:meal_app/core/widgets/wallet_checkout_section.dart';



/// Pays a configured upgrade fee to move a recipient to a larger meal size.

class MealSizeUpgradeScreen extends StatefulWidget {

  final String? initialEntityType;

  final String? initialEntityId;

  final String? initialEntityName;



  const MealSizeUpgradeScreen({

    super.key,

    this.initialEntityType,

    this.initialEntityId,

    this.initialEntityName,

  });



  @override

  State<MealSizeUpgradeScreen> createState() => _MealSizeUpgradeScreenState();

}



class _MealSizeUpgradeScreenState extends State<MealSizeUpgradeScreen> {

  List<Map<String, dynamic>> _upgradeOptions = [];

  String? _currentSizeName;

  bool _loading = true;

  bool _loadingOptions = false;

  String? _error;



  int _selectedSubIndex = 0;

  int? _toMealSizeId;
  String? _walletBalance;
  bool _eligible = false;
  String? _eligibleMessage;
  bool _useWallet = true;
  bool _loadingWalletPreview = false;
  double? _walletApplied;
  double? _gatewayAmount;
  int _resizeCount = 0;
  int _maxResizes = 2;

  static double _parseMoney(dynamic value) {
    if (value == null) return 0;
    return double.tryParse(value.toString().replaceAll(',', '')) ?? 0;
  }



  static String _trim(dynamic v) => (v ?? '').toString().trim();



  static int? _int(dynamic v) => int.tryParse('$v');

  String _subscriptionMealSizeLabel(Map<dynamic, dynamic> sub, {bool selected = false}) {
    if (selected && _currentSizeName != null && _currentSizeName!.isNotEmpty) {
      return _currentSizeName!;
    }
    return _trim(sub['meal_size_name']);
  }



  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _load());

  }



  Future<void> _load() async {

    final pay = context.read<PaymentProvider>();

    setState(() {

      _loading = true;

      _error = null;

      _toMealSizeId = null;

    });

    try {

      await Future.wait([
        pay.fetchActiveSubscriptions(force: true),
        pay.fetchPaymentHistory(force: true),
      ]);

      if (!mounted) return;

      var pickIndex = 0;
      final et = widget.initialEntityType?.trim() ?? '';
      final eid = widget.initialEntityId?.trim() ?? '';

      if (et.isNotEmpty && eid.isNotEmpty) {
        for (var i = 0; i < pay.activeSubscriptions.length; i++) {
          final row = pay.activeSubscriptions[i];
          if (row is! Map) continue;
          final m = Map<String, dynamic>.from(row);
          final subEt = _trim(m['entity_type']).toLowerCase();
          final subEid = _trim(m['entity_id']);
          if (subEt == et.toLowerCase() && subEid == eid) {
            pickIndex = i;
            break;
          }
        }
      }

      final n = pay.activeSubscriptions.length;
      _selectedSubIndex = n == 0 ? 0 : pickIndex.clamp(0, n - 1);

      await _loadOptionsForSelected();

    } catch (e) {

      if (!mounted) return;

      setState(() {

        _error = ErrorHandler.getErrorMessage(e);

      });

    } finally {

      if (mounted) setState(() => _loading = false);

    }

  }



  Future<void> _loadOptionsForSelected() async {
    final pay = context.read<PaymentProvider>();
    final entity = _selectedEntity(pay);
    if (entity == null) {
      if (mounted) {
        setState(() {
          _upgradeOptions = [];
          _currentSizeName = null;
        });
      }
      return;
    }

    setState(() => _loadingOptions = true);
    try {
      final payload = await pay.fetchMealSizeUpgradeOptionsForEntity(
        entityType: entity['entity_type']!,
        entityId: entity['entity_id']!,
      );
      if (!mounted) return;
      final data = (payload['data'] as List?) ?? [];
      final eligibleRaw = payload['eligible'];
      final eligible = eligibleRaw == null ? data.isNotEmpty : eligibleRaw == true;
      setState(() {
        _currentSizeName = _trim(payload['current_meal_size_name']);
        _walletBalance = _trim(payload['wallet_balance']);
        _eligible = eligible;
        _eligibleMessage = _trim(payload['message']);
        _resizeCount = _int(payload['resize_count']) ?? 0;
        _maxResizes = _int(payload['max_resizes']) ?? 2;
        if (_currentSizeName!.isNotEmpty && _selectedSubIndex < pay.activeSubscriptions.length) {
          final selected = pay.activeSubscriptions[_selectedSubIndex];
          if (selected is Map) {
            final updated = Map<String, dynamic>.from(selected);
            updated['meal_size_name'] = _currentSizeName;
            pay.activeSubscriptions[_selectedSubIndex] = updated;
          }
        }
        _upgradeOptions = [
          for (final raw in data)
            if (raw is Map) Map<String, dynamic>.from(raw),
        ];
        _toMealSizeId = null;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ErrorHandler.getErrorMessage(e);
        _upgradeOptions = [];
        _eligible = false;
        _eligibleMessage = null;
      });
    } finally {
      if (mounted) setState(() => _loadingOptions = false);
    }
  }

  Map<String, String>? _selectedEntity(PaymentProvider pay) {
    final subs = pay.activeSubscriptions;
    if (subs.isEmpty || _selectedSubIndex >= subs.length || subs[_selectedSubIndex] is! Map) {
      return null;
    }
    final sub = Map<String, dynamic>.from(subs[_selectedSubIndex] as Map);
    final et = _trim(sub['entity_type']);
    final eid = _trim(sub['entity_id']);
    if (et.isEmpty || eid.isEmpty) return null;
    return {'entity_type': et, 'entity_id': eid};
  }

  List<Map<String, dynamic>> _optionsForDirection(String direction) {
    final out = <Map<String, dynamic>>[];
    for (final m in _upgradeOptions) {
      if (_trim(m['direction']).toLowerCase() != direction) continue;
      final t = _int(m['to_meal_size_id']);
      final toName = _trim(m['to_display_name']);
      if (t == null || toName.isEmpty) continue;
      final isDowngrade = direction == 'downgrade';
      final flatPrice = _trim(m['flat_price']);
      final priceVal = _trim(m['price']);

      String subtitle = isDowngrade ? 'Credit to wallet' : 'One-time fee';
      if (priceVal != flatPrice && flatPrice.isNotEmpty) {
        subtitle = isDowngrade
            ? 'Credit: ₹${MoneyFormat.display(priceVal)} (Prorated from ₹${MoneyFormat.display(flatPrice)})'
            : 'Fee: ₹${MoneyFormat.display(priceVal)} (Prorated from ₹${MoneyFormat.display(flatPrice)})';
      }

      out.add({
        'to_id': t,
        'label': toName,
        'subtitle': subtitle,
        'price': MoneyFormat.display(priceVal),
        'flat_price': MoneyFormat.display(flatPrice),
        'direction': direction,
      });
    }
    return out;
  }

  String? _selectedDirection() {
    if (_toMealSizeId == null) return null;
    for (final m in _upgradeOptions) {
      if (_int(m['to_meal_size_id']) == _toMealSizeId) {
        return _trim(m['direction']).toLowerCase();
      }
    }
    return null;
  }

  double? _selectedUpgradePrice() {
    if (_toMealSizeId == null || _selectedDirection() != 'upgrade') return null;
    for (final m in _upgradeOptions) {
      if (_int(m['to_meal_size_id']) != _toMealSizeId) continue;
      return _parseMoney(m['price']);
    }
    return null;
  }

  Future<void> _refreshUpgradeWalletPreview() async {
    final price = _selectedUpgradePrice();
    if (!mounted) return;
    if (price == null || price <= 0) {
      setState(() {
        _walletApplied = null;
        _gatewayAmount = null;
      });
      return;
    }

    setState(() => _loadingWalletPreview = true);
    try {
      final pay = context.read<PaymentProvider>();
      final preview = await pay.previewWalletForTotal(price, useWallet: _useWallet);
      if (!mounted) return;
      setState(() {
        _walletApplied = _parseMoney(preview['walletApplied']);
        _gatewayAmount = _parseMoney(preview['gatewayAmount']);
      });
    } catch (_) {
      // Optional breakdown — payment still works without preview.
    } finally {
      if (mounted) setState(() => _loadingWalletPreview = false);
    }
  }

  void _onUseWalletChanged(bool value) {
    setState(() => _useWallet = value);
    _refreshUpgradeWalletPreview();
  }



  List<Map<String, dynamic>> _upgradeHistory(PaymentProvider pay) =>
      filterMealSizeUpgradePayments(pay.paymentHistory);

  Future<void> _pickSubscriber(List<dynamic> subs, bool isDark) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Who is resizing?',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.xmark_circle_fill),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: subs.length,
                  itemBuilder: (_, i) {
                    final sub = subs[i] as Map;
                    final name = _trim(sub['entity_name']).isNotEmpty
                        ? _trim(sub['entity_name'])
                        : widget.initialEntityName ?? 'Subscriber';
                    final plan = _trim(sub['plan_name']);
                    final mealSize = _subscriptionMealSizeLabel(
                      sub,
                      selected: i == _selectedSubIndex,
                    );
                    final selected = i == _selectedSubIndex;
                    final subtitleParts = <String>[
                      if (plan.isNotEmpty) plan,
                      if (mealSize.isNotEmpty) 'Meal size: $mealSize',
                    ];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                        child: Icon(CupertinoIcons.person_fill, color: AppTheme.primaryColor, size: 20),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: subtitleParts.isNotEmpty ? Text(subtitleParts.join(' • ')) : null,
                      trailing: selected
                          ? const Icon(CupertinoIcons.checkmark_circle_fill, color: AppTheme.primaryColor)
                          : null,
                      onTap: () => Navigator.pop(ctx, i),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedSubIndex = picked;
      _currentSizeName = null;
      _toMealSizeId = null;
    });
    await _loadOptionsForSelected();
  }

  Future<void> _runPayment() async {
    final pay = context.read<PaymentProvider>();
    final entity = _selectedEntity(pay);
    if (_toMealSizeId == null || entity == null) return;

    final res = await pay.initiateMealSizeUpgrade(
      entityType: entity['entity_type']!,
      entityId: entity['entity_id']!,
      toMealSizeId: _toMealSizeId!,
      isSandbox: ApiEndpoints.isTestModePayment,
      useWallet: _useWallet,
    );



    if (!mounted) return;



    if (pay.error != null && res == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pay.error!)));
      return;
    }

    final sdkStatus = res?['sdkStatus']?.toString() ?? 'FAILURE';
    final txnId = res?['merchantTransactionId']?.toString() ?? pay.lastTxnId ?? '';
    final orderId = res?['orderId']?.toString() ?? '';

    if (sdkStatus == 'SUCCESS' || sdkStatus == 'EXTERNAL_WALLET') {
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        CupertinoPageRoute(
          builder: (_) => PaymentStatusScreen(
            txnId: txnId,
            orderId: orderId,
            orderType: 'meal_size_upgrade',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          (sdkStatus == 'CANCELLED' || sdkStatus == 'INTERRUPTED')
              ? 'Payment cancelled. Wallet balance has been restored.'
              : 'Payment did not complete. You can retry when ready.',
        ),
      ),
    );
  }

  Future<void> _runDowngrade() async {
    final pay = context.read<PaymentProvider>();
    final entity = _selectedEntity(pay);
    if (_toMealSizeId == null || entity == null) return;

    final result = await pay.applyMealSizeDowngrade(
      entityType: entity['entity_type']!,
      entityId: entity['entity_id']!,
      toMealSizeId: _toMealSizeId!,
    );

    if (!mounted) return;

    if (pay.error != null && result == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(pay.error!)));
      return;
    }

    final message = result?['message']?.toString() ??
        'Meal pack resized. Wallet credited.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    setState(() {
      _toMealSizeId = null;
      _walletBalance = pay.walletBalance;
    });
    await _loadOptionsForSelected();
  }

  Future<void> _confirmAction() async {
    final direction = _selectedDirection();
    if (direction == 'downgrade') {
      await _runDowngrade();
    } else {
      await _runPayment();
    }
  }


  @override
  Widget build(BuildContext context) {
    final pay = context.watch<PaymentProvider>();
    final subs = pay.activeSubscriptions;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final history = _upgradeHistory(pay);

    Map<String, dynamic>? selectedMap;
    if (subs.isNotEmpty && subs[_selectedSubIndex.clamp(0, subs.length - 1)] is Map) {
      selectedMap = Map<String, dynamic>.from(subs[_selectedSubIndex.clamp(0, subs.length - 1)] as Map);
    }

    final upgrades = _optionsForDirection('upgrade');
    final downgrades = _optionsForDirection('downgrade');
    final hasAnyOptions = upgrades.isNotEmpty || downgrades.isNotEmpty;
    final selectedDirection = _selectedDirection();

    final currentSize =
        (_currentSizeName != null && _currentSizeName!.isNotEmpty)
            ? _currentSizeName!
            : _trim(selectedMap?['meal_size_name']);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayFor(
        background: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
        isDark: isDark,
        navigationBarColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: Text(
            'Resize meal pack',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF5A4D42),
            ),
          ),
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back, color: Color(0xFF8B7A66)),
            onPressed: () => Navigator.pop(context),
          ),
          systemOverlayStyle: AppTheme.overlayFor(
            background: isDark ? AppTheme.surfaceDark : const Color(0xFFF3EBE0),
            isDark: isDark,
            navigationBarColor: isDark ? AppTheme.surfaceDark : const Color(0xFFFAF8F5),
          ),
        ),
        body: SafeArea(
          top: false,
          child: _loading && subs.isEmpty
              ? const Center(child: CupertinoActivityIndicator())
              : Column(
                  children: [
                    Expanded(
                    child: RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        children: [
                          if (_error != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.orange.withValues(alpha: 0.15) : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.orange.shade200 : Colors.orange.shade900,
                                ),
                              ),
                            ),

                          Text(
                            'Move to a larger pack and pay a one-time fee, or downsize and receive the amount in your wallet.',
                            style: TextStyle(
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 20),

                          if (_walletBalance != null && _walletBalance!.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isDark 
                                      ? [const Color(0xFF332D29), const Color(0xFF26211E)]
                                      : [const Color(0xFFFFF7ED), const Color(0xFFFFEDD5)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF453D37) : const Color(0xFFFFD8A8),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withValues(alpha: isDark ? 0.05 : 0.03),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(24),
                                onTap: () => Navigator.push(
                                  context,
                                  CupertinoPageRoute(builder: (_) => const WalletScreen()),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(18),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(CupertinoIcons.creditcard_fill, color: AppTheme.primaryColor, size: 24),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Wallet Balance',
                                              style: TextStyle(
                                                fontSize: 11, 
                                                fontWeight: FontWeight.w800, 
                                                color: isDark ? Colors.white60 : const Color(0xFFC2410C),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '₹${MoneyFormat.display(_walletBalance)}',
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w900,
                                                color: isDark ? Colors.white : const Color(0xFF7C2D12),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(CupertinoIcons.chevron_right, color: AppTheme.primaryColor, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                          if (subs.isEmpty)
                            Text(
                              'No active or upcoming paid meal plans found. Buy a meal plan first, then you can resize the meal pack.',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white54 : Colors.grey.shade700,
                              ),
                            )
                          else ...[
                            _sectionTitle(context, 'Recipient profile'),
                            const SizedBox(height: 8),

                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2B2521) : Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF3B332D) : const Color(0xFFEEDFD2),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(28),
                                onTap: () => _pickSubscriber(subs, isDark),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 22,
                                            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                                            child: const Icon(CupertinoIcons.person_crop_circle_fill, color: AppTheme.primaryColor, size: 24),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Recipient Profile',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    color: isDark ? Colors.white54 : AppTheme.textSecondaryLight,
                                                  ),
                                                ),
                                                Text(
                                                  _trim((subs[_selectedSubIndex.clamp(0, subs.length - 1)] as Map)['entity_name'])
                                                          .isNotEmpty
                                                      ? _trim((subs[_selectedSubIndex.clamp(0, subs.length - 1)] as Map)['entity_name'])
                                                      : widget.initialEntityName ?? 'Subscriber',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w900, 
                                                    fontSize: 18,
                                                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF3D342C) : const Color(0xFFFAF2EB),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  'Change',
                                                  style: TextStyle(
                                                    fontSize: 12, 
                                                    fontWeight: FontWeight.w800, 
                                                    color: AppTheme.primaryColor
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(CupertinoIcons.chevron_down, color: AppTheme.primaryColor, size: 14),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      const Divider(height: 1, thickness: 1.2),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Current Plan',
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? Colors.white54 : AppTheme.textSecondaryLight),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _trim((subs[_selectedSubIndex.clamp(0, subs.length - 1)] as Map)['plan_name']).isNotEmpty
                                                      ? _trim((subs[_selectedSubIndex.clamp(0, subs.length - 1)] as Map)['plan_name'])
                                                      : 'Active Meal Plan',
                                                  style: TextStyle(
                                                    fontSize: 14, 
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (currentSize.isNotEmpty)
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  'Meal Size',
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? Colors.white54 : AppTheme.textSecondaryLight),
                                                ),
                                                const SizedBox(height: 2),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.primaryColor,
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Text(
                                                    currentSize.toUpperCase(),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w900,
                                                      color: Colors.white,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            _buildResizePolicyCard(context, isDark),
                            _buildResizeQuotaCard(context, isDark),

                            if (_toMealSizeId != null) ...[
                              const SizedBox(height: 16),
                              Builder(
                                builder: (context) {
                                  final isDowngrade = selectedDirection == 'downgrade';
                                  final selectedOption = _upgradeOptions.firstWhere(
                                    (o) => _int(o['to_meal_size_id']) == _toMealSizeId,
                                    orElse: () => <String, dynamic>{},
                                  );
                                  final toName = _trim(selectedOption['to_display_name'] ?? selectedOption['label']);
                                  final price = _trim(selectedOption['price']);
                                  return Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: isDowngrade 
                                          ? (isDark ? const Color(0xFF1B2F22) : const Color(0xFFF0FDF4))
                                          : (isDark ? const Color(0xFF382315) : const Color(0xFFFFF7ED)),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: isDowngrade 
                                            ? (isDark ? const Color(0xFF2E5A39) : const Color(0xFFBBF7D0))
                                            : (isDark ? const Color(0xFF6E4327) : const Color(0xFFFFEDD5)),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Text(
                                                    currentSize,
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w900,
                                                      color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Icon(
                                                    isDowngrade ? CupertinoIcons.left_chevron : CupertinoIcons.right_chevron,
                                                    color: isDowngrade ? const Color(0xFF22C55E) : AppTheme.primaryColor,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    toName,
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w900,
                                                      color: isDowngrade ? const Color(0xFF22C55E) : AppTheme.primaryColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  isDowngrade ? 'Refund Credit' : 'Payment Due',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: isDowngrade ? const Color(0xFF16A34A) : AppTheme.primaryColor,
                                                  ),
                                                ),
                                                Text(
                                                  isDowngrade ? '+₹$price' : '₹$price',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w900,
                                                    color: isDowngrade ? const Color(0xFF22C55E) : AppTheme.primaryColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),

                                      ],
                                    ),
                                  );
                                }
                              ),
                            ],

                            const SizedBox(height: 20),
                            _sectionTitle(context, 'Choose new size'),
                            const SizedBox(height: 8),

                            if (_loadingOptions)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(child: CupertinoActivityIndicator()),
                              )
                            else if (!hasAnyOptions)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.surfaceDark : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  !_eligible
                                      ? (_eligibleMessage != null && _eligibleMessage!.isNotEmpty
                                          ? _eligibleMessage!
                                          : 'This profile does not have an active meal plan yet. Buy a meal plan first, then resize options will appear here.')
                                      : 'No resizing path is published from your current size yet. Contact support if you need to change your pack.',
                                  style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white70 : AppTheme.textPrimaryLight),
                                ),
                              )
                            else ...[
                              if (upgrades.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                ..._buildOptionTiles(upgrades, isDark),
                                const SizedBox(height: 16),
                              ],
                              if (downgrades.isNotEmpty) ...[
                                _sectionTitle(context, 'Smaller packs (wallet credit)'),
                                const SizedBox(height: 8),
                                ..._buildOptionTiles(downgrades, isDark),
                              ],
                            ],

                            const SizedBox(height: 8),

                            if (selectedDirection == 'upgrade' && _selectedUpgradePrice() != null)
                              WalletCheckoutSection(
                                useWallet: _useWallet,
                                onUseWalletChanged: _onUseWalletChanged,
                                walletBalance: _walletBalance ?? pay.walletBalance,
                                walletApplied: _walletApplied,
                                gatewayAmount: _gatewayAmount,
                                totalAmount: _selectedUpgradePrice(),
                                loadingPreview: _loadingWalletPreview,
                              ),

                            if (selectedDirection == 'upgrade' && _selectedUpgradePrice() != null)
                              const SizedBox(height: 16),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: pay.isLoading || _toMealSizeId == null || !hasAnyOptions || !_eligible ? null : _confirmAction,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: selectedDirection == 'downgrade' ? const Color(0xFF22C55E) : AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: isDark ? const Color(0xFF332A24) : Colors.grey.shade300,
                                  disabledForegroundColor: Colors.grey.shade500,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  elevation: 3,
                                  shadowColor: (selectedDirection == 'downgrade' ? const Color(0xFF22C55E) : AppTheme.primaryColor).withValues(alpha: 0.4),
                                ),
                                child: Text(
                                  pay.isLoading
                                      ? 'Please wait…'
                                      : selectedDirection == 'downgrade'
                                          ? 'Confirm & credit wallet'
                                          : 'Pay',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ],

                          if (history.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            _sectionTitle(context, 'Resize history'),
                            const SizedBox(height: 12),
                            ...history.take(20).map((h) {
                              final amount = MoneyFormat.display(h['amount'] ?? h['order_amount'] ?? h['amount_paid']);
                              final status = _trim(h['order_status'] ?? h['status'] ?? h['payment_status']).toUpperCase();
                              final when = _trim(h['created_at'] ?? h['createdAt']);
                              final who = _trim(h['entity_name'] ?? h['entityName']);
                              final plan = _trim(h['plan_name'] ?? h['planName']);
                              final isSuccess = status == 'COMPLETED' || status == 'SUCCESS';

                              DateTime date = DateTime.now();
                              if (when.isNotEmpty) {
                                date = DateTime.tryParse(when) ?? DateTime.now();
                              }

                              final fromName = _trim(h['from_display_name'] ?? h['from_meal_size_name'] ?? h['fromMealSizeName']);
                              final toName = _trim(h['to_display_name'] ?? h['to_meal_size_name'] ?? h['meal_size_name']);
                              final changeLabel = _trim(h['size_change_label']);

                              String sizeChangeText = '';
                              if (changeLabel.isNotEmpty) {
                                sizeChangeText = changeLabel;
                              } else if (fromName.isNotEmpty && toName.isNotEmpty) {
                                sizeChangeText = '$fromName → $toName';
                              } else if (toName.isNotEmpty) {
                                sizeChangeText = 'To $toName';
                              }

                              final titleText = who.isNotEmpty
                                  ? (sizeChangeText.isNotEmpty ? '$who ($sizeChangeText)' : who)
                                  : (sizeChangeText.isNotEmpty ? 'Resize ($sizeChangeText)' : plan);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF2B2521) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF3D342C) : const Color(0xFFEEDFD2),
                                    width: 1.2,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                                  leading: CircleAvatar(
                                    backgroundColor: (isSuccess ? Colors.green : Colors.orange).withValues(alpha: 0.12),
                                    child: Icon(
                                      isSuccess ? CupertinoIcons.checkmark_alt : CupertinoIcons.clock,
                                      color: isSuccess ? Colors.green : Colors.orange,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    titleText, 
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                    ),
                                  ),
                                  subtitle: Text(
                                    DateFormat('dd MMM yyyy, hh:mm a').format(date),
                                    style: TextStyle(
                                      fontSize: 12, 
                                      color: isDark ? Colors.white54 : AppTheme.textSecondaryLight
                                    ),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹$amount', 
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (isSuccess ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          status,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: isSuccess ? Colors.green : Colors.orange,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    ),
  ),
);
  }

  Widget _buildResizePolicyCard(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2B2521) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF4A3B2C) : const Color(0xFFFDE68A),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.info_circle_fill,
                color: Color(0xFFD97706),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Meal Pack Resizing Rules & Policy',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.amber.shade200 : const Color(0xFF92400E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _policyPoint('Prorated Rates', 'Charges & credits are calculated strictly on your remaining unused meals against full cycle days.', isDark),
          const SizedBox(height: 8),
          _policyPoint('Wallet Credits for Downgrades', 'Moving to a smaller pack credits the prorated refund instantly to your Buuttii Wallet.', isDark),
          const SizedBox(height: 8),
          _policyPoint('24-Hour Cooldown', 'To ensure kitchen preparation stability, pack resizing is permitted once every 24 hours per active subscription.', isDark),
          const SizedBox(height: 8),
          _policyPoint('Billing Rounding', 'All prorated calculation amounts round up to the nearest rupee per official billing guidelines.', isDark),
        ],
      ),
    );
  }

  Widget _buildResizeQuotaCard(BuildContext context, bool isDark) {
    final isMaxedOut = _resizeCount >= _maxResizes;
    final remaining = (_maxResizes - _resizeCount).clamp(0, _maxResizes);

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMaxedOut
            ? (isDark ? const Color(0xFF3F1D1D) : const Color(0xFFFEF2F2))
            : (isDark ? const Color(0xFF1E2D24) : const Color(0xFFF0FDF4)),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isMaxedOut
              ? (isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5))
              : (isDark ? const Color(0xFF166534) : const Color(0xFF86EFAC)),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isMaxedOut
                  ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2))
                  : (isDark ? const Color(0xFF14532D) : const Color(0xFFDCFCE7)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isMaxedOut ? CupertinoIcons.lock_fill : CupertinoIcons.slider_horizontal_3,
              color: isMaxedOut ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMaxedOut ? 'Resize Limit Reached' : 'Resizes Allowance',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isMaxedOut
                        ? (isDark ? Colors.red.shade200 : const Color(0xFF991B1B))
                        : (isDark ? Colors.green.shade200 : const Color(0xFF166534)),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isMaxedOut
                      ? 'You have used both of your 2 permitted resizes for this subscription.'
                      : '$remaining of $_maxResizes resizes remaining for this subscription cycle.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isMaxedOut ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '$_resizeCount / $_maxResizes',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _policyPoint(String title, String desc, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Icon(
            CupertinoIcons.checkmark_seal_fill,
            size: 14,
            color: isDark ? Colors.amber.shade400 : const Color(0xFFD97706),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: isDark ? Colors.white70 : const Color(0xFF78350F),
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w900,
        color: isDark ? Colors.white : AppTheme.textPrimaryLight,
      ),
    );
  }

  List<Widget> _buildOptionTiles(List<Map<String, dynamic>> options, bool isDark) {
    return options.map((t) {
      final id = _int(t['to_id']);
      if (id == null) return const SizedBox.shrink();
      final selected = _toMealSizeId == id;
      final isDowngrade = _trim(t['direction']) == 'downgrade';

      Color activeColor = isDowngrade ? const Color(0xFF22C55E) : AppTheme.primaryColor;
      Color activeBg = isDowngrade 
          ? (isDark ? const Color(0xFF1B2F22) : const Color(0xFFF0FDF4))
          : (isDark ? const Color(0xFF382315) : const Color(0xFFFFF7ED));

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: selected
              ? activeBg
              : (isDark ? const Color(0xFF25201C) : Colors.white),
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: () {
              setState(() => _toMealSizeId = id);
              _refreshUpgradeWalletPreview();
            },
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: selected ? activeColor : (isDark ? const Color(0xFF352D28) : const Color(0xFFEEDFD2)),
                  width: selected ? 2.5 : 1.5,
                ),
                boxShadow: selected ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: isDark ? 0.2 : 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ] : null,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? activeColor : Colors.grey.shade400,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 6,
                      backgroundColor: selected ? activeColor : Colors.transparent,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _trim(t['label']),
                          style: TextStyle(
                            fontWeight: FontWeight.w900, 
                            fontSize: 16,
                            color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _trim(t['subtitle']),
                          style: TextStyle(
                            fontSize: 12, 
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white54 : AppTheme.textSecondaryLight
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? activeColor.withValues(alpha: 0.15)
                          : (isDark ? const Color(0xFF2D2521) : const Color(0xFFFAF2EB)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isDowngrade ? '+₹${_trim(t['price'])}' : '₹${_trim(t['price'])}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: isDowngrade ? const Color(0xFF22C55E) : AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}

