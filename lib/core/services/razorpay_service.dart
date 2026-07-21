import 'dart:async';
import 'dart:convert';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'dart:developer' as dev;

class RazorpayService {
  RazorpayService._();

  /// Parses the Razorpay error message, which may be a JSON string, to extract
  /// a human-readable description. Falls back to raw string or a default.
  static String _parseErrorMessage(String? raw) {
    if (raw == null || raw.isEmpty) return 'Payment was not completed';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map) {
          return error['description']?.toString() ?? error['reason']?.toString() ?? raw;
        }
        return decoded['description']?.toString() ?? raw;
      }
    } catch (_) {}
    return raw;
  }

  static Future<Map<String, dynamic>> pay({
    required String razorpayOrderId,
    required String keyId,
    required double amount,
    required String currency,
    String? contact,
    String? email,
  }) async {
    final completer = Completer<Map<String, dynamic>>();
    final razorpay = Razorpay();

    void handlePaymentSuccess(PaymentSuccessResponse response) {
      dev.log('Razorpay Payment Success: paymentId=${response.paymentId}, orderId=${response.orderId}');
      if (!completer.isCompleted) {
        completer.complete({
          'status': 'SUCCESS',
          'paymentId': response.paymentId,
          'orderId': response.orderId,
          'signature': response.signature,
        });
      }
      razorpay.clear();
    }

    void handlePaymentError(PaymentFailureResponse response) {
      dev.log('Razorpay Payment Error: code=${response.code}, message=${response.message}');
      final humanMessage = _parseErrorMessage(response.message);
      final msgLower = (response.message ?? '').toLowerCase();
      final isCancelled = response.code == 2 ||
          msgLower.contains('cancel') ||
          msgLower.contains('dismiss') ||
          msgLower.contains('exit') ||
          msgLower.contains('back');
      if (!completer.isCompleted) {
        completer.complete({
          'status': isCancelled ? 'CANCELLED' : 'FAILURE',
          'code': response.code,
          'error': isCancelled ? 'Payment cancelled by user' : humanMessage,
        });
      }
      razorpay.clear();
    }

    void handleExternalWallet(ExternalWalletResponse response) {
      dev.log('Razorpay External Wallet: name=${response.walletName}');
      // External wallet selection does NOT mean payment succeeded.
      // The user is redirected to the wallet app; actual success/failure
      // comes back through the success or error callbacks, or via webhook.
      // We treat this as a PENDING state so the status screen polls for result.
      if (!completer.isCompleted) {
        completer.complete({
          'status': 'EXTERNAL_WALLET',
          'walletName': response.walletName,
        });
      }
      razorpay.clear();
    }

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, handlePaymentSuccess);
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, handlePaymentError);
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, handleExternalWallet);

    final options = {
      'key': keyId,
      'amount': (amount * 100).round(), // Convert Rupees to Paise for Razorpay SDK
      'name': 'Buuttii',
      'order_id': razorpayOrderId,
      'description': 'Meal Subscription Payment',
      'timeout': 300, // 5 minutes
      'prefill': {
        if (contact != null) 'contact': contact,
        if (email != null) 'email': email,
      }
    };

    try {
      razorpay.open(options);
    } catch (e) {
      dev.log('Razorpay Open Error: $e');
      if (!completer.isCompleted) {
        completer.complete({
          'status': 'FAILURE',
          'error': e.toString(),
        });
      }
      razorpay.clear();
    }

    return completer.future;
  }
}

