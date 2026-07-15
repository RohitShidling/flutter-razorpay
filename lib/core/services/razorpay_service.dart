import 'dart:async';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'dart:developer' as dev;

class RazorpayService {
  RazorpayService._();

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
      if (!completer.isCompleted) {
        completer.complete({
          'status': 'FAILURE',
          'code': response.code,
          'error': response.message,
        });
      }
      razorpay.clear();
    }

    void handleExternalWallet(ExternalWalletResponse response) {
      dev.log('Razorpay External Wallet: name=${response.walletName}');
      if (!completer.isCompleted) {
        completer.complete({
          'status': 'SUCCESS',
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
