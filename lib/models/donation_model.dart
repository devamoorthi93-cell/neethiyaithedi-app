import 'package:cloud_firestore/cloud_firestore.dart';

class DonationRecord {
  final String id;
  final String userId;
  final String userName;
  final double amount;
  final DateTime timestamp;
  final String paymentId;
  final String status;
  final String? message;

  DonationRecord({
    required this.id,
    required this.userId,
    required this.userName,
    required this.amount,
    required this.timestamp,
    required this.paymentId,
    required this.status,
    this.message,
  });

  factory DonationRecord.fromMap(String id, Map<String, dynamic> map) {
    return DonationRecord(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Unknown',
      amount: (map['amount'] ?? 0.0).toDouble(),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      paymentId: map['paymentId'] ?? '',
      status: map['status'] ?? 'pending',
      message: map['message'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'amount': amount,
      'timestamp': Timestamp.fromDate(timestamp),
      'paymentId': paymentId,
      'status': status,
      'message': message,
    };
  }
}
