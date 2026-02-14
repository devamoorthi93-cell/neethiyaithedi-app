/// Centralized Razorpay & Payment Configuration
///
/// When [useMockPayment] is true, the app simulates a successful payment
/// after a short delay — no real Razorpay key needed.
/// Set to false and provide a real key when ready for production.
class PaymentConfig {
  // ─── Mode ─────────────────────────────────────────────────────────
  /// Set to true to simulate payments without a real Razorpay key.
  /// Set to false and provide a real key for production.
  static const bool useMockPayment = true;

  // ─── Razorpay API Key ─────────────────────────────────────────────
  // Replace with your real test key from Razorpay Dashboard when ready
  static const String razorpayKey = 'rzp_test_YOUR_KEY_HERE';

  // ─── Payment Amounts (INR) ────────────────────────────────────────
  static const double membershipFee = 100.0;  // Monthly membership
  static const double petitionFee   = 50.0;   // Per petition generation

  // ─── Amounts in Paise (for Razorpay API) ──────────────────────────
  static int get membershipFeeInPaise => (membershipFee * 100).toInt();
  static int get petitionFeeInPaise   => (petitionFee * 100).toInt();

  // ─── Display Strings ─────────────────────────────────────────────
  static const String merchantName = 'Neethiyaithedi';
  static const String currency     = 'INR';
  static const String themeColor   = '#1A1A2E';
}
