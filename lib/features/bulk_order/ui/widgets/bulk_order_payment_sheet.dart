import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/theme/app_theme.dart';
import 'package:meal_app/core/utils/delivery_time_window.dart';
import 'package:meal_app/core/utils/time_utils.dart';
import 'package:meal_app/core/providers/lookup_provider.dart';
import 'package:meal_app/features/bulk_order/data/models/bulk_delivery_address.dart';
import 'package:meal_app/features/bulk_order/data/models/bulk_order_config.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_order_address_section.dart';
import 'package:meal_app/features/bulk_order/ui/widgets/bulk_order_widgets.dart';

/// Collects delivery date, time, and address immediately before payment.
class BulkOrderPaymentSheet extends StatefulWidget {
  const BulkOrderPaymentSheet({
    super.key,
    required this.config,
    required this.onConfirm,
    this.initialDeliveryDate,
    this.isStandardBulk = false,
  });

  final BulkOrderConfig config;
  final Future<void> Function(String deliveryDate) onConfirm;
  final String? initialDeliveryDate;
  final bool isStandardBulk;

  static Future<bool?> show(
    BuildContext context, {
    required BulkOrderConfig config,
    required Future<void> Function(String deliveryDate) onConfirm,
    String? initialDeliveryDate,
    bool isStandardBulk = false,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => BulkOrderPaymentSheet(
        config: config,
        onConfirm: onConfirm,
        initialDeliveryDate: initialDeliveryDate,
        isStandardBulk: isStandardBulk,
      ),
    );
  }

  @override
  State<BulkOrderPaymentSheet> createState() => _BulkOrderPaymentSheetState();
}

class _BulkOrderPaymentSheetState extends State<BulkOrderPaymentSheet> {
  String? _deliveryDate;
  TimeOfDay? _deliveryTime;
  bool _paying = false;
  String? _sheetError;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _deliveryDate = widget.initialDeliveryDate;
    final saved = context.read<BulkOrderProvider>().deliveryAddress?.deliveryTime;
    if (saved != null && saved.isNotEmpty) {
      final parsed = TimeUtils.tryParseToBackend(saved);
      if (parsed != null) {
        final parts = parsed.split(':');
        if (parts.length >= 2) {
          _deliveryTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 13,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
    }
  }

  Future<void> _pickDate() async {
    final ymd = await pickBulkDeliveryDate(context, widget.config, _deliveryDate);
    if (ymd != null && mounted) {
      setState(() {
        _deliveryDate = ymd;
        _sheetError = null;
      });
    }
  }

  Future<void> _pickTime() async {
    final lookup = context.read<LookupProvider>();
    if (lookup.deliveryTimeSettings == null) {
      await lookup.fetchDeliveryTimeSettings();
      if (!mounted) return;
    }
    final window = lookup.deliveryTimeSettings;
    final picked = await showTimePicker(
      context: context,
      initialTime: _deliveryTime ?? const TimeOfDay(hour: 13, minute: 0),
    );
    if (picked != null && mounted) {
      if (!DeliveryTimeWindow.allows(picked, window)) {
        _setSheetError(DeliveryTimeWindow.message(window));
        return;
      }
      setState(() {
        _deliveryTime = picked;
        _sheetError = null;
      });
    }
  }

  void _setSheetError(String message) {
    setState(() => _sheetError = message);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  void _syncDeliveryTimeToProvider() {
    final provider = context.read<BulkOrderProvider>();
    final addr = provider.deliveryAddress;
    if (addr == null || _deliveryTime == null) return;
    provider.setDeliveryAddress(
      BulkDeliveryAddress(
        stateId: addr.stateId,
        cityId: addr.cityId,
        addressLine: addr.addressLine,
        pincode: addr.pincode,
        stateName: addr.stateName,
        cityName: addr.cityName,
        deliveryTime: TimeUtils.toBackendFormat(_deliveryTime!),
        phoneNumber: addr.phoneNumber,
        altPhoneNumber: addr.altPhoneNumber,
      ),
    );
  }

  Future<void> _pay() async {
    if (_deliveryDate == null) {
      _setSheetError('Select a delivery date.');
      return;
    }

    // Enforce next-day minimum — no same-day orders
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    if (_deliveryDate!.compareTo(todayStr) <= 0) {
      _setSheetError('Delivery date must be tomorrow or later. Same-day orders are not allowed.');
      return;
    }

    if (_deliveryTime == null) {
      _setSheetError('Select a delivery time.');
      return;
    }
    _syncDeliveryTimeToProvider();

    final provider = context.read<BulkOrderProvider>();
    final addrErr = provider.validateDeliveryAddress(requireTime: true);
    if (addrErr != null) {
      _setSheetError(addrErr);
      return;
    }

    setState(() {
      _paying = true;
      _sheetError = null;
    });
    final deliveryDate = _deliveryDate!;
    if (mounted) {
      Navigator.pop(context, true);
    }
    await widget.onConfirm(deliveryDate);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.88,
        child: Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Delivery & payment',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(CupertinoIcons.xmark_circle_fill),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    Text(
                      'Enter where and when meals should arrive. We validate everything before payment.',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    BulkDeliveryDateTile(
                      deliveryDate: _deliveryDate,
                      onTap: _pickDate,
                      enabled: !widget.isStandardBulk,
                    ),
                    if (widget.isStandardBulk)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 6),
                        child: Text(
                          'Delivery date is fixed for standard bulk items.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        final window = context.watch<LookupProvider>().deliveryTimeSettings;
                        final hint = DeliveryTimeWindow.hint(window);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey.shade300,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                title: Text(
                                  'Delivery time',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white70 : AppTheme.textSecondaryLight,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    _deliveryTime == null
                                        ? 'Tap to choose'
                                        : TimeUtils.formatToDisplay(TimeUtils.toBackendFormat(_deliveryTime!)),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _deliveryTime != null
                                          ? (isDark ? Colors.white : AppTheme.textPrimaryLight)
                                          : (isDark ? Colors.white38 : Colors.grey.shade400),
                                    ),
                                  ),
                                ),
                                trailing: Icon(
                                  CupertinoIcons.clock,
                                  color: isDark ? Colors.white70 : AppTheme.textPrimaryLight,
                                ),
                                onTap: _pickTime,
                              ),
                            ),
                            if (hint != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6, left: 4),
                                child: Text(
                                  hint,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const BulkOrderAddressSection(),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_sheetError != null) ...[
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.orange.withValues(alpha: 0.14) : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? Colors.orange.withValues(alpha: 0.35) : Colors.orange.shade200,
                            ),
                          ),
                          child: Text(
                            _sheetError!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.orange.shade200 : Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: _paying ? null : _pay,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _paying
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Proceed to Pay', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        ),
                      ),
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
