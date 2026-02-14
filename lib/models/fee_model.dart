
/// Fee configuration model for monthly membership fees
class FeeConfiguration {
  final double monthlyAmount;
  final int dueDay; // Day of month when fee is due
  final String currency;

  const FeeConfiguration({
    this.monthlyAmount = 100.0,
    this.dueDay = 5,
    this.currency = 'INR',
  });

  factory FeeConfiguration.fromMap(Map<String, dynamic> map) {
    return FeeConfiguration(
      monthlyAmount: (map['monthlyAmount'] ?? 100.0).toDouble(),
      dueDay: map['dueDay'] ?? 5,
      currency: map['currency'] ?? 'INR',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'monthlyAmount': monthlyAmount,
      'dueDay': dueDay,
      'currency': currency,
    };
  }

  /// Check if current date is past due day
  bool isOverdue() {
    return DateTime.now().day > dueDay;
  }

  /// Get amount in paise for Razorpay
  int get amountInPaise => (monthlyAmount * 100).toInt();
}

/// Member's fee status for tracking payments
class MemberFeeStatus {
  final String memberId;
  final String memberName;
  final String? membershipId;
  final String phone;
  final String? lastPaymentMonth;
  final bool isPaidCurrentMonth;
  final bool isOverdue;
  final DateTime? lastPaymentDate;

  MemberFeeStatus({
    required this.memberId,
    required this.memberName,
    this.membershipId,
    required this.phone,
    this.lastPaymentMonth,
    required this.isPaidCurrentMonth,
    required this.isOverdue,
    this.lastPaymentDate,
  });

  /// Get formatted status text
  String get statusText {
    if (isPaidCurrentMonth) return 'Paid';
    if (isOverdue) return 'Overdue';
    return 'Pending';
  }
}
