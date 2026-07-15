import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/providers/lookup_provider.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_order_address_section.dart';
import 'package:meal_app/features/quick_service/providers/quick_service_provider.dart';
import 'package:meal_app/features/bulk_order/data/models/bulk_delivery_address.dart';
import 'package:meal_app/features/subscription/ui/screens/payment_status_screen.dart';

class QuickServiceCheckout {
  QuickServiceCheckout._();

  static void _openStatusScreen(
    BuildContext context, {
    required String txnId,
    required String orderId,
    required String orderType,
  }) {
    Navigator.pushReplacement(
      context,
      CupertinoPageRoute(
        builder: (_) => PaymentStatusScreen(
          txnId: txnId,
          orderId: orderId,
          orderType: orderType,
        ),
      ),
    );
  }

  static Future<void> chooseOneDayLunch(BuildContext context) async {
    await _hydrateSavedAddress(context);
    if (!context.mounted) return;
    await context.read<LookupProvider>().fetchInitialData();
    if (!context.mounted) return;

    final confirmed = await showModalBottomSheet<_OneDayLunchChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => const _OneDayLunchSheet(),
    );
    if (confirmed == null || !context.mounted) return;

    await _completeOneDayLunch(
      context,
      deliveryType: confirmed.deliveryType,
      quantity: confirmed.quantity,
      mealSizeId: confirmed.mealSizeId,
      deliveryTime: confirmed.deliveryTime,
    );
  }

  static Future<void> payOneDayLunch(
    BuildContext context, {
    required String deliveryType,
    int quantity = 1,
    int? mealSizeId,
    String? deliveryTime,
    bool skipAddressPrompt = false,
  }) async {
    if (!skipAddressPrompt) {
      await _hydrateSavedAddress(context);
      if (!context.mounted) return;
    }
    final bulk = context.read<BulkOrderProvider>();

    int resolvedMealSizeId = mealSizeId ?? 0;
    if (resolvedMealSizeId == 0) {
      final sizes = context.read<LookupProvider>().mealSizes;
      final recommended = sizes.where((m) => m.displayName.toLowerCase().contains('medium')).firstOrNull;
      resolvedMealSizeId = recommended?.id ?? (sizes.isNotEmpty ? sizes.first.id : 0);
    }

    String resolvedDeliveryTime = deliveryTime ?? '';
    if (resolvedDeliveryTime.isEmpty) {
      resolvedDeliveryTime = bulk.deliveryAddress?.deliveryTime ?? '';
    }

    if (skipAddressPrompt) {
      final err = bulk.validateDeliveryAddress(requireTime: true);
      if (err != null) {
        ErrorHandler.showError(context, err);
        return;
      }
      if (resolvedDeliveryTime.isEmpty) {
        ErrorHandler.showError(context, 'Select a delivery time.');
        return;
      }
      await _completeOneDayLunch(
        context,
        deliveryType: deliveryType,
        quantity: quantity,
        mealSizeId: resolvedMealSizeId,
        deliveryTime: resolvedDeliveryTime,
      );
      return;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => _AddressSheet(
        title: deliveryType == 'today' ? 'Order for today' : 'Order for tomorrow',
        showDeliveryTime: true,
        onConfirm: () => Navigator.pop(ctx, true),
      ),
    );
    if (confirmed != true || !context.mounted) return;

    String finalDeliveryTime = deliveryTime ?? '';
    if (finalDeliveryTime.isEmpty) {
      finalDeliveryTime = bulk.deliveryAddress?.deliveryTime ?? '';
    }

    if (finalDeliveryTime.isEmpty) {
      ErrorHandler.showError(context, 'Select a delivery time.');
      return;
    }

    await _completeOneDayLunch(
      context,
      deliveryType: deliveryType,
      quantity: quantity,
      mealSizeId: resolvedMealSizeId,
      deliveryTime: finalDeliveryTime,
    );
  }

  static Future<void> _completeOneDayLunch(
    BuildContext context, {
    required String deliveryType,
    required int quantity,
    required int mealSizeId,
    required String deliveryTime,
  }) async {
    final bulk = context.read<BulkOrderProvider>();
    final provider = context.read<QuickServiceProvider>();
    provider.setAddress(bulk.deliveryAddress);

    final result = await provider.payOneDayLunch(
      deliveryType: deliveryType,
      quantity: quantity,
      mealSizeId: mealSizeId,
      deliveryTime: deliveryTime,
    );
    if (!context.mounted) return;

    if (result != null) {
      final txnId = result['merchantTransactionId']?.toString() ?? '';
      final orderId = result['orderId']?.toString() ?? '';
      if (txnId.isNotEmpty) {
        _openStatusScreen(
          context,
          txnId: txnId,
          orderId: orderId,
          orderType: 'one_day_lunch',
        );
        return;
      }
    }
    if (provider.error != null) {
      ErrorHandler.showError(context, provider.error!);
    }
  }

  static Future<void> paySpecialDishes(
    BuildContext context, {
    bool skipAddressPrompt = false,
  }) async {
    if (!skipAddressPrompt) {
      await _hydrateSavedAddress(context);
      if (!context.mounted) return;
    }
    final bulk = context.read<BulkOrderProvider>();

    if (skipAddressPrompt) {
      final err = bulk.validateDeliveryAddress(requireTime: true);
      if (err != null) {
        ErrorHandler.showError(context, err);
        return;
      }
      await _completeSpecialDishes(context);
      return;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => _AddressSheet(
        title: 'Confirm delivery address',
        showDeliveryTime: true,
        onConfirm: () => Navigator.pop(ctx, true),
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await _completeSpecialDishes(context);
  }

  static Future<void> _completeSpecialDishes(BuildContext context) async {
    final bulk = context.read<BulkOrderProvider>();
    final provider = context.read<QuickServiceProvider>();
    provider.setAddress(bulk.deliveryAddress);

    final result = await provider.paySpecialDishes();
    if (!context.mounted) return;

    if (result != null) {
      final txnId = result['merchantTransactionId']?.toString() ?? '';
      final orderId = result['orderId']?.toString() ?? '';
      if (txnId.isNotEmpty) {
        _openStatusScreen(
          context,
          txnId: txnId,
          orderId: orderId,
          orderType: 'special_dish',
        );
        return;
      }
    }
    if (provider.error != null) {
      ErrorHandler.showError(context, provider.error!);
    }
  }

  static Future<void> _hydrateSavedAddress(BuildContext context) async {
    final bulk = context.read<BulkOrderProvider>();
    await bulk.loadSavedDeliveryAddress();
    if (!context.mounted) return;

    final quick = context.read<QuickServiceProvider>();
    final backendAddress = await quick.loadSavedDeliveryAddress();
    if (!context.mounted) return;

    final address = backendAddress ?? bulk.deliveryAddress;
    if (address != null) {
      final addressWithoutTime = BulkDeliveryAddress(
        id: address.id,
        label: address.label,
        stateId: address.stateId,
        cityId: address.cityId,
        addressLine: address.addressLine,
        pincode: address.pincode,
        stateName: address.stateName,
        cityName: address.cityName,
        isDefault: address.isDefault,
        deliveryTime: null,
        phoneNumber: address.phoneNumber,
        altPhoneNumber: address.altPhoneNumber,
      );
      bulk.setDeliveryAddress(addressWithoutTime);
      quick.setAddress(addressWithoutTime);
    }
  }
}

class _OneDayLunchChoice {
  const _OneDayLunchChoice({
    required this.deliveryType,
    required this.mealSizeId,
    required this.deliveryTime,
    required this.quantity,
  });

  final String deliveryType;
  final int mealSizeId;
  final String deliveryTime;
  final int quantity;
}

class _OneDayLunchSheet extends StatefulWidget {
  const _OneDayLunchSheet();

  @override
  State<_OneDayLunchSheet> createState() => _OneDayLunchSheetState();
}

class _OneDayLunchSheetState extends State<_OneDayLunchSheet> {
  String _deliveryType = 'today';
  int? _mealSizeId;
  int _quantity = 1;
  final _timeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final sizes = context.read<LookupProvider>().mealSizes;
    final recommended = sizes.where((m) => m.displayName.toLowerCase().contains('medium')).firstOrNull;
    _mealSizeId = recommended?.id ?? (sizes.isNotEmpty ? sizes.first.id : null);
  }

  @override
  void dispose() {
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final cfg = context.watch<QuickServiceProvider>().oneDayConfig;
    final sizes = context.watch<LookupProvider>().mealSizes;
    final todayPrice = double.tryParse(cfg?['today_price']?.toString() ?? '') ?? 100.0;
    final nextDayPrice = double.tryParse(cfg?['next_day_price']?.toString() ?? '') ?? 90.0;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('One day lunch', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                'Choose today or tomorrow, meal size, time, and delivery address.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ChoicePill(
                      selected: _deliveryType == 'today',
                      title: 'Today',
                      subtitle: 'Rs ${todayPrice.toStringAsFixed(0)}',
                      onTap: () => setState(() => _deliveryType = 'today'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ChoicePill(
                      selected: _deliveryType == 'next_day',
                      title: 'Next day',
                      subtitle: 'Rs ${nextDayPrice.toStringAsFixed(0)}',
                      onTap: () => setState(() => _deliveryType = 'next_day'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Meal size', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: sizes.map((m) {
                  final selected = _mealSizeId == m.id;
                  final isRecommended = m.displayName.toLowerCase().contains('medium') ||
                      m.displayName.toLowerCase().contains('large');
                  return ChoiceChip(
                    selected: selected,
                    label: Text('${m.displayName}${isRecommended ? ' (Recommended)' : ''}'),
                    onSelected: (_) => setState(() => _mealSizeId = m.id),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Quantity', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                          iconSize: 18,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '$_quantity',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => setState(() => _quantity++),
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                          iconSize: 18,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              BulkOrderAddressSection(
                showDeliveryTime: true,
                deliveryTimeController: _timeController,
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    final bulk = context.read<BulkOrderProvider>();
                    final err = bulk.validateDeliveryAddress(requireTime: true);
                    if (err != null) {
                      ErrorHandler.showError(context, err);
                      return;
                    }
                    if (_timeController.text.trim().isEmpty) {
                      ErrorHandler.showError(context, 'Select a delivery time.');
                      return;
                    }
                    final mealSizeId = _mealSizeId;
                    if (mealSizeId == null) {
                      ErrorHandler.showError(context, 'Select a meal size.');
                      return;
                    }
                    Navigator.pop(
                      context,
                      _OneDayLunchChoice(
                        deliveryType: _deliveryType,
                        mealSizeId: mealSizeId,
                        deliveryTime: _timeController.text.trim(),
                        quantity: _quantity,
                      ),
                    );
                  },
                  child: const Text('Continue to payment', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    )
    );
  }

}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primaryColor)),
          ],
        ),
      ),
    );
  }
}

class _AddressSheet extends StatefulWidget {
  const _AddressSheet({
    required this.title,
    required this.onConfirm,
    this.showDeliveryTime = false,
  });

  final String title;
  final VoidCallback onConfirm;
  final bool showDeliveryTime;

  @override
  State<_AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends State<_AddressSheet> {
  final _timeController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  widget.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Enter where we should deliver your order.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      BulkOrderAddressSection(
                        showDeliveryTime: widget.showDeliveryTime,
                        deliveryTimeController: widget.showDeliveryTime ? _timeController : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      final err = context.read<BulkOrderProvider>().validateDeliveryAddress(
                        requireTime: widget.showDeliveryTime,
                      );
                      if (err != null) {
                        ErrorHandler.showError(context, err);
                        return;
                      }
                      if (widget.showDeliveryTime && _timeController.text.trim().isEmpty) {
                        ErrorHandler.showError(context, 'Select a delivery time.');
                        return;
                      }
                      widget.onConfirm();
                    },
                    child: const Text('Continue to payment', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
