import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/providers/lookup_provider.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';
import 'package:meal_app/features/bulk_order/data/models/bulk_delivery_address.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_order_address_section.dart';
import 'package:meal_app/features/quick_service/providers/quick_service_provider.dart';
import 'package:meal_app/features/subscription/ui/screens/payment_status_screen.dart';
import 'package:meal_app/core/providers/payment_provider.dart';
import 'package:meal_app/core/utils/delivery_time_window.dart';

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
    String? customerName,
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
    if (resolvedDeliveryTime.isEmpty && !skipAddressPrompt) {
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
        customerName: customerName,
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
        onConfirm: (_) => Navigator.pop(ctx, true),
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
      customerName: customerName,
    );
  }

  static Future<void> _completeOneDayLunch(
    BuildContext context, {
    required String deliveryType,
    required int quantity,
    required int mealSizeId,
    required String deliveryTime,
    String? customerName,
  }) async {
    final bulk = context.read<BulkOrderProvider>();
    final provider = context.read<QuickServiceProvider>();
    
    final addr = bulk.deliveryAddress;
    if (addr != null && customerName != null && customerName.isNotEmpty) {
      final updatedAddr = BulkDeliveryAddress(
        id: addr.id,
        label: addr.label,
        stateId: addr.stateId,
        cityId: addr.cityId,
        addressLine: addr.addressLine,
        pincode: addr.pincode,
        stateName: addr.stateName,
        cityName: addr.cityName,
        isDefault: addr.isDefault,
        deliveryTime: addr.deliveryTime,
        phoneNumber: addr.phoneNumber,
        altPhoneNumber: addr.altPhoneNumber,
        customerName: customerName,
      );
      provider.setAddress(updatedAddr);
    } else {
      provider.setAddress(addr);
    }

    final result = await provider.payOneDayLunch(
      deliveryType: deliveryType,
      quantity: quantity,
      mealSizeId: mealSizeId,
      deliveryTime: deliveryTime,
    );
    if (!context.mounted) return;

    if (result != null) {
      final sdkStatus = result['sdkStatus']?.toString() ?? 'FAILURE';
      final txnId = result['merchantTransactionId']?.toString() ?? '';
      final orderId = result['orderId']?.toString() ?? '';

      if (sdkStatus == 'SUCCESS' || sdkStatus == 'EXTERNAL_WALLET') {
        if (txnId.isNotEmpty) {
          _openStatusScreen(
            context,
            txnId: txnId,
            orderId: orderId,
            orderType: 'one_day_lunch',
          );
          return;
        }
      } else if (sdkStatus == 'CANCELLED') {
        await context.read<PaymentProvider>().abandonPendingPayment(
          orderId: orderId.isNotEmpty ? orderId : null,
          merchantTransactionId: txnId.isNotEmpty ? txnId : null,
        );
        if (context.mounted) {
          ErrorHandler.showError(context, 'Payment cancelled.');
        }
        return;
      } else {
        await context.read<PaymentProvider>().abandonPendingPayment(
          orderId: orderId.isNotEmpty ? orderId : null,
          merchantTransactionId: txnId.isNotEmpty ? txnId : null,
        );
        if (context.mounted) {
          final errStr = result['error']?.toString() ?? provider.error;
          ErrorHandler.showError(context, errStr ?? 'Payment failed.');
        }
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
    await context.read<QuickServiceProvider>().loadSpecialConfig();
    if (!context.mounted) return;
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

    final selectedDate = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => _AddressSheet(
        title: 'Confirm delivery details',
        showDeliveryTime: true,
        showDeliveryDate: true,
        onConfirm: (dateStr) => Navigator.pop(ctx, dateStr ?? ''),
      ),
    );
    if (selectedDate == null || !context.mounted) return;

    await _completeSpecialDishes(context, deliveryDate: selectedDate);
  }

  static Future<void> _completeSpecialDishes(BuildContext context, {String? deliveryDate}) async {
    final bulk = context.read<BulkOrderProvider>();
    final provider = context.read<QuickServiceProvider>();
    provider.setAddress(bulk.deliveryAddress);

    final result = await provider.paySpecialDishes(deliveryDate: deliveryDate);
    if (!context.mounted) return;

    if (result != null) {
      final sdkStatus = result['sdkStatus']?.toString() ?? 'FAILURE';
      final txnId = result['merchantTransactionId']?.toString() ?? '';
      final orderId = result['orderId']?.toString() ?? '';

      if (sdkStatus == 'SUCCESS' || sdkStatus == 'EXTERNAL_WALLET') {
        if (txnId.isNotEmpty) {
          _openStatusScreen(
            context,
            txnId: txnId,
            orderId: orderId,
            orderType: 'special_dish',
          );
          return;
        }
      } else if (sdkStatus == 'CANCELLED') {
        await context.read<PaymentProvider>().abandonPendingPayment(
          orderId: orderId.isNotEmpty ? orderId : null,
          merchantTransactionId: txnId.isNotEmpty ? txnId : null,
        );
        if (context.mounted) {
          ErrorHandler.showError(context, 'Payment cancelled.');
        }
        return;
      } else {
        await context.read<PaymentProvider>().abandonPendingPayment(
          orderId: orderId.isNotEmpty ? orderId : null,
          merchantTransactionId: txnId.isNotEmpty ? txnId : null,
        );
        if (context.mounted) {
          final errStr = result['error']?.toString() ?? provider.error;
          ErrorHandler.showError(context, errStr ?? 'Payment failed.');
        }
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
      bulk.setDeliveryAddress(address);
      quick.setAddress(address);
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
  final _timeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final sizes = context.read<LookupProvider>().mealSizes.where((m) => m.isAvailableForOneDayLunch).toList();
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
    final sizes = context.watch<LookupProvider>().mealSizes.where((m) => m.isAvailableForOneDayLunch).toList();
    final customPricing = cfg?['custom_pricing'] as Map<String, dynamic>?;
    final sizeIdStr = _mealSizeId?.toString() ?? '';
    final specificPricing = customPricing?[sizeIdStr] as Map<String, dynamic>?;

    final defaultToday = double.tryParse(cfg?['today_price']?.toString() ?? '') ?? 100.0;
    final defaultNext = double.tryParse(cfg?['next_day_price']?.toString() ?? '') ?? 90.0;

    final todayPrice = specificPricing != null 
        ? (double.tryParse(specificPricing['today']?.toString() ?? '') ?? defaultToday)
        : defaultToday;
        
    final nextDayPrice = specificPricing != null
        ? (double.tryParse(specificPricing['next_day']?.toString() ?? '') ?? defaultNext)
        : defaultNext;

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
              BulkOrderAddressSection(
                showDeliveryTime: true,
                deliveryTimeController: _timeController,
                autoPopulateDeliveryTime: false,
                isStandardRequired: false,
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
                        quantity: 1,
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
    this.showDeliveryDate = false,
  });

  final String title;
  final ValueChanged<String?> onConfirm;
  final bool showDeliveryTime;
  final bool showDeliveryDate;

  @override
  State<_AddressSheet> createState() => _AddressSheetState();
}

class _AddressSheetState extends State<_AddressSheet> {
  final _timeController = TextEditingController();
  String? _selectedDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bulk = context.read<BulkOrderProvider>();
      if (bulk.deliveryAddress != null) {
        final updated = BulkDeliveryAddress(
          id: bulk.deliveryAddress!.id,
          label: bulk.deliveryAddress!.label,
          stateId: bulk.deliveryAddress!.stateId,
          cityId: bulk.deliveryAddress!.cityId,
          addressLine: bulk.deliveryAddress!.addressLine,
          pincode: bulk.deliveryAddress!.pincode,
          stateName: bulk.deliveryAddress!.stateName,
          cityName: bulk.deliveryAddress!.cityName,
          isDefault: bulk.deliveryAddress!.isDefault,
          deliveryTime: null,
          phoneNumber: bulk.deliveryAddress!.phoneNumber,
          altPhoneNumber: bulk.deliveryAddress!.altPhoneNumber,
          customerName: bulk.deliveryAddress!.customerName,
        );
        bulk.setDeliveryAddress(updated);
      }
    });
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
    final lookup = context.watch<LookupProvider>();

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
                      // 1. Delivery Address section
                      BulkOrderAddressSection(
                        showDeliveryTime: widget.showDeliveryDate ? false : widget.showDeliveryTime,
                        deliveryTimeController: (!widget.showDeliveryDate && widget.showDeliveryTime) ? _timeController : null,
                        autoPopulateDeliveryTime: false,
                        isStandardRequired: false,
                      ),

                      // 2. Delivery Date (placed directly above Delivery Time for Buuttii Specials)
                      if (widget.showDeliveryDate) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Delivery Date *',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final now = DateTime.now();
                            final minLeadDays = context.read<QuickServiceProvider>().specialMinLeadDays;
                            final earliestDate = now.add(Duration(days: minLeadDays));
                            final firstDate = DateTime(earliestDate.year, earliestDate.month, earliestDate.day);
                            final todayZero = DateTime(now.year, now.month, now.day);
                            final lastDate = todayZero.add(const Duration(days: 60));

                            DateTime initialDate = firstDate;
                            if (_selectedDate != null && _selectedDate!.isNotEmpty) {
                              final parsed = DateTime.tryParse(_selectedDate!);
                              if (parsed != null && !parsed.isBefore(firstDate)) {
                                initialDate = parsed;
                              }
                            }

                            if (initialDate.weekday == DateTime.sunday) {
                              initialDate = initialDate.add(const Duration(days: 1));
                            }

                            final picked = await showDatePicker(
                              context: context,
                              initialDate: initialDate,
                              firstDate: firstDate,
                              lastDate: lastDate,
                              selectableDayPredicate: (date) => date.weekday != DateTime.sunday && !date.isBefore(firstDate),
                            );
                            if (picked != null) {
                              setState(() {
                                _selectedDate = DateFormat('yyyy-MM-dd').format(picked);
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.surfaceDark : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(CupertinoIcons.calendar, color: AppTheme.primaryColor, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _selectedDate != null && _selectedDate!.isNotEmpty
                                        ? _selectedDate!
                                        : 'Select Delivery Date',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _selectedDate != null && _selectedDate!.isNotEmpty
                                          ? (isDark ? Colors.white : AppTheme.textPrimaryLight)
                                          : Colors.grey.shade600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                Icon(
                                  CupertinoIcons.chevron_down,
                                  size: 16,
                                  color: Colors.grey.shade500,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      // 3. Delivery Time (placed directly below Delivery Date for Buuttii Specials)
                      if (widget.showDeliveryDate && widget.showDeliveryTime) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Delivery Time *',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _timeController,
                          readOnly: true,
                          decoration: InputDecoration(
                            hintText: DeliveryTimeWindow.hint(lookup.deliveryTimeSettings) ??
                                'Select preferred delivery time',
                            helperText: DeliveryTimeWindow.hint(lookup.deliveryTimeSettings),
                            helperMaxLines: 2,
                            prefixIcon: const Icon(Icons.access_time, color: AppTheme.primaryColor),
                            suffixIcon: Icon(CupertinoIcons.chevron_down, size: 16, color: Colors.grey.shade500),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight, width: 1.5),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: isDark ? AppTheme.borderDark : AppTheme.borderLight, width: 1.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                            ),
                          ),
                          onTap: () async {
                            if (lookup.deliveryTimeSettings == null) {
                              await lookup.fetchDeliveryTimeSettings();
                              if (!context.mounted) return;
                            }
                            final window = lookup.deliveryTimeSettings;
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (picked == null || !context.mounted) return;
                            if (!DeliveryTimeWindow.allows(picked, window)) {
                              ErrorHandler.showError(context, DeliveryTimeWindow.message(window));
                              return;
                            }
                            final formattedTime = MaterialLocalizations.of(context).formatTimeOfDay(picked);
                            setState(() {
                              _timeController.text = formattedTime;
                            });
                            final selected = context.read<BulkOrderProvider>().deliveryAddress;
                            if (selected != null) {
                              final updated = BulkDeliveryAddress(
                                id: selected.id,
                                label: selected.label,
                                stateId: selected.stateId,
                                cityId: selected.cityId,
                                addressLine: selected.addressLine,
                                pincode: selected.pincode,
                                stateName: selected.stateName,
                                cityName: selected.cityName,
                                isDefault: selected.isDefault,
                                deliveryTime: formattedTime,
                                phoneNumber: selected.phoneNumber,
                                altPhoneNumber: selected.altPhoneNumber,
                                customerName: selected.customerName,
                              );
                              context.read<BulkOrderProvider>().setDeliveryAddress(updated);
                            }
                          },
                        ),
                      ],
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
                      final provider = context.read<BulkOrderProvider>();
                      final err = provider.validateDeliveryAddress(
                        requireTime: false,
                      );
                      if (err != null) {
                        ErrorHandler.showError(context, err);
                        return;
                      }

                      if (widget.showDeliveryDate) {
                        final hasDate = _selectedDate != null && _selectedDate!.trim().isNotEmpty;
                        final hasTime = _timeController.text.trim().isNotEmpty;

                        if (!hasDate && !hasTime) {
                          ErrorHandler.showError(context, 'Please select both delivery date and delivery time.');
                          return;
                        }
                        if (!hasDate) {
                          ErrorHandler.showError(context, 'Please select a delivery date.');
                          return;
                        }
                        if (!hasTime) {
                          ErrorHandler.showError(context, 'Please select a delivery time.');
                          return;
                        }
                      } else if (widget.showDeliveryTime) {
                        if (_timeController.text.trim().isEmpty) {
                          ErrorHandler.showError(context, 'Please select a delivery time.');
                          return;
                        }
                      }

                      final timeText = _timeController.text.trim();
                      final selectedAddr = provider.deliveryAddress;
                      if (selectedAddr != null && timeText.isNotEmpty) {
                        final updated = BulkDeliveryAddress(
                          id: selectedAddr.id,
                          label: selectedAddr.label,
                          stateId: selectedAddr.stateId,
                          cityId: selectedAddr.cityId,
                          addressLine: selectedAddr.addressLine,
                          pincode: selectedAddr.pincode,
                          stateName: selectedAddr.stateName,
                          cityName: selectedAddr.cityName,
                          isDefault: selectedAddr.isDefault,
                          deliveryTime: timeText,
                          phoneNumber: selectedAddr.phoneNumber,
                          altPhoneNumber: selectedAddr.altPhoneNumber,
                          customerName: selectedAddr.customerName,
                        );
                        provider.setDeliveryAddress(updated);
                      }

                      widget.onConfirm(_selectedDate);
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
