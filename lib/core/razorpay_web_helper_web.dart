import 'dart:js' as js;

class RazorpayWebHelper {
  final Function(String paymentId, String? orderId, String? signature) onPaymentSuccess;
  final Function(String error) onPaymentError;

  RazorpayWebHelper({
    required this.onPaymentSuccess,
    required this.onPaymentError,
  });

  void open(Map<String, dynamic> options) {
    // Convert options to JsObject-friendly map
    final jsOptions = js.JsObject.jsify(options);
    
    // Call the global function we added to index.html
    js.context.callMethod('openRazorpayCheckout', [
      jsOptions,
      js.JsObject.jsify({
        'onPaymentSuccess': (String paymentId, String? orderId, String? signature) {
          onPaymentSuccess(paymentId, orderId, signature);
        },
        'onPaymentError': (String error) {
          onPaymentError(error);
        },
      }),
    ]);
  }
}
