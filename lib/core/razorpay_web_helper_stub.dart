import '../models/user_model.dart';

class RazorpayWebHelper {
  final Function(String paymentId, String? orderId, String? signature) onPaymentSuccess;
  final Function(String error) onPaymentError;

  RazorpayWebHelper({
    required this.onPaymentSuccess,
    required this.onPaymentError,
  });

  void open(Map<String, dynamic> options) {
    // Stub: does nothing on mobile/desktop as they use the plugin
  }
}
