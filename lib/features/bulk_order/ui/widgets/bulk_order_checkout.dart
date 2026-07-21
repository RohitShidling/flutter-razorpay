import 'package:flutter/cupertino.dart';
import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/utils/error_handler.dart';
import 'package:meal_app/core/utils/time_utils.dart';
import 'package:meal_app/features/bulk_order/providers/bulk_order_provider.dart';
import 'package:provider/provider.dart';
import 'package:meal_app/core/providers/payment_provider.dart';
import 'package:meal_app/features/subscription/ui/screens/payment_status_screen.dart';

class BulkOrderCheckout {
  BulkOrderCheckout._();

  static void _openStatusScreen(
    BuildContext context, {
    required String txnId,
    required String orderId,
  }) {
    Navigator.pushReplacement(
      context,
      CupertinoPageRoute(
        builder: (_) => PaymentStatusScreen(
          txnId: txnId,
          orderId: orderId,
          orderType: 'bulk',
        ),
      ),
    );
  }

  static Future<void> pay({
    required BuildContext context,
    required BulkOrderProvider provider,
    required String deliveryDate,
    required List<Map<String, dynamic>> items,
    required int totalMeals,
    String? summaryLines,
    bool useBundle = false,
  }) async {
    final addrErr = provider.validateDeliveryAddress(requireTime: true);
    if (addrErr != null) {
      ErrorHandler.showError(context, addrErr);
      return;
    }
    final addressPayload = provider.deliveryAddress!.toApiPayload();

    final cfg = provider.config;
    final isVarietyOrder = items.any((e) => e['bulkMealId'] != null);
    if (cfg != null && isVarietyOrder && !useBundle) {
      final cartErr = provider.validateVarietyCart(cfg, forPayment: true);
      if (cartErr != null) {
        ErrorHandler.showError(context, cartErr);
        return;
      }
    }

    if (!useBundle) {
      final quote = await provider.fetchQuote(
        deliveryDate: deliveryDate,
        items: items,
        deliveryAddress: addressPayload,
      );
      if (!context.mounted) return;
      if (quote == null) {
        if (provider.error != null) ErrorHandler.showError(context, provider.error);
        return;
      }
    }

    final addr = provider.deliveryAddress;
    final body = StringBuffer()..writeln('Delivery: $deliveryDate');
    final deliveryTime = addr?.deliveryTime?.trim();
    if (deliveryTime != null && deliveryTime.isNotEmpty) {
      body.writeln('Time: ${TimeUtils.formatToDisplay(deliveryTime)}');
    }
    body
      ..writeln('Address: ${addr?.formatted ?? '—'}')
      ..writeln('Total meals: $totalMeals');
    if (summaryLines != null && summaryLines.isNotEmpty) {
      body.writeln(summaryLines);
    }

    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Confirm bulk order'),
        content: Text(body.toString()),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Pay'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    final result = useBundle
        ? await provider.checkoutBundle(
            deliveryDate: deliveryDate,
            deliveryAddress: addressPayload,
            isSandbox: ApiEndpoints.isTestModePayment,
          )
        : await provider.checkout(
            deliveryDate: deliveryDate,
            items: items,
            deliveryAddress: addressPayload,
            isSandbox: ApiEndpoints.isTestModePayment,
          );
    if (!context.mounted) return;
    if (result != null) {
      final sdkStatus = result['sdkStatus']?.toString() ?? 'FAILURE';
      final txnId = result['merchantTransactionId']?.toString() ?? '';
      final orderId = result['orderId']?.toString() ?? '';

      if (sdkStatus == 'SUCCESS' || sdkStatus == 'EXTERNAL_WALLET') {
        if (txnId.isNotEmpty && context.mounted) {
          _openStatusScreen(context, txnId: txnId, orderId: orderId);
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
          final errStr = result['sdkError']?.toString() ?? provider.error;
          ErrorHandler.showError(context, errStr ?? 'Payment failed.');
        }
        return;
      }
    } else if (provider.error != null) {
      ErrorHandler.showError(context, provider.error);
    }
  }
}
