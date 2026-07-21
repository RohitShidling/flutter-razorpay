import 'package:meal_app/core/network/api_endpoints.dart';
import 'package:meal_app/core/network/payment_repository.dart';
import 'package:meal_app/core/services/razorpay_service.dart';

/// Completes checkout after backend payment init — wallet-only or Razorpay SDK.
class WalletPaymentFlow {
  static Future<Map<String, dynamic>> completeAfterInit({
    required Map<String, dynamic> paymentData,
    required bool isSandbox,
    PaymentRepository? paymentRepository,
  }) async {
    final walletOnly = paymentData['walletOnly'] == true;

    if (walletOnly) {
      return {
        ...paymentData,
        'sdkStatus': 'SUCCESS',
        'sdkError': null,
      };
    }

    final razorpayOrderId = paymentData['razorpayOrderId']?.toString();
    final keyId = paymentData['keyId']?.toString();
    final amount = (paymentData['gatewayAmount'] as num?)?.toDouble() ?? 0.0;
    final currency = paymentData['currency']?.toString() ?? 'INR';
    final contact = paymentData['contact']?.toString();
    final email = paymentData['email']?.toString();

    if (razorpayOrderId == null || razorpayOrderId.isEmpty || keyId == null || keyId.isEmpty) {
      throw Exception('Payment information not received from gateway');
    }

    final sdkResult = await RazorpayService.pay(
      razorpayOrderId: razorpayOrderId,
      keyId: keyId,
      amount: amount,
      currency: currency,
      contact: contact,
      email: email,
    );

    final status = sdkResult['status']?.toString() ?? 'FAILURE';
    final result = {
      ...paymentData,
      'sdkStatus': status,
      'sdkError': sdkResult['error'],
      'paymentId': sdkResult['paymentId'],
      'signature': sdkResult['signature'],
    };

    if (status == 'SUCCESS' && paymentRepository != null) {
      final paymentId = sdkResult['paymentId']?.toString();
      final orderId = sdkResult['orderId']?.toString() ?? razorpayOrderId;
      final signature = sdkResult['signature']?.toString();
      final merchantTxnId = paymentData['merchantTransactionId']?.toString();

      if (paymentId != null && signature != null) {
        try {
          await paymentRepository.verifyPaymentSignature(
            razorpayOrderId: orderId,
            razorpayPaymentId: paymentId,
            razorpaySignature: signature,
            merchantTransactionId: merchantTxnId,
          );
        } catch (_) {
          // Signature verification best-effort — fallback to status polling / webhook.
        }
      }
    }

    // Only abandon for definitive failures. EXTERNAL_WALLET means the user
    // was redirected to a wallet app — the payment may still complete via
    // webhook. CANCELLED is handled by the caller (cart/payment screen).
    if (status == 'FAILURE' && paymentRepository != null) {
      await abandonPendingPayment(paymentRepository, paymentData);
    }

    return result;
  }

  /// Refund wallet debited at initiate when user cancels or Razorpay does not succeed.
  static Future<void> abandonPendingPayment(
    PaymentRepository repository,
    Map<String, dynamic> paymentData,
  ) async {
    final orderId = paymentData['orderId']?.toString();
    final txnId = paymentData['merchantTransactionId']?.toString();
    if ((orderId == null || orderId.isEmpty) && (txnId == null || txnId.isEmpty)) {
      return;
    }
    try {
      await repository.abandonPendingPayment(
        orderId: orderId,
        merchantTransactionId: txnId,
      );
    } catch (_) {
      // Best-effort — status screen may retry abandon on back navigation.
    }
  }
}

/// Whether Razorpay SDK should run for this init response.
bool paymentNeedsGateway(Map<String, dynamic> paymentData) {
  if (paymentData['walletOnly'] == true) return false;
  final razorpayOrderId = paymentData['razorpayOrderId']?.toString() ?? '';
  return razorpayOrderId.isNotEmpty;
}

bool get defaultSandbox => ApiEndpoints.isTestModePayment;
