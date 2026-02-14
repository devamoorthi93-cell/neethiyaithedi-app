import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentStatus { pending, success, failed }

class PaymentModel {
  final String paymentId;
  final String userId;
  final double amount;
  final String month; // YYYY-MM
  final DateTime timestamp;
  final PaymentStatus status;
  final String method;
  final String? gatewayOrderId;

  PaymentModel({
    required this.paymentId,
    required this.userId,
    required this.amount,
    required this.month,
    required this.timestamp,
    required this.status,
    required this.method,
    this.gatewayOrderId,
  });

  factory PaymentModel.fromMap(Map<String, dynamic> map) {
    return PaymentModel(
      paymentId: map['paymentId'] ?? '',
      userId: map['userId'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      month: map['month'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      status: PaymentStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PaymentStatus.pending,
      ),
      method: map['method'] ?? 'Unknown',
      gatewayOrderId: map['gatewayOrderId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'paymentId': paymentId,
      'userId': userId,
      'amount': amount,
      'month': month,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status.name,
      'method': method,
      'gatewayOrderId': gatewayOrderId,
    };
  }
}
