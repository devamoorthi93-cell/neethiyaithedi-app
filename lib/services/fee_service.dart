import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/fee_model.dart';
import '../models/user_model.dart';

/// Service for managing membership fees
class FeeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Default fee configuration
  static const FeeConfiguration defaultFee = FeeConfiguration(
    monthlyAmount: 100.0,
    dueDay: 10,
    currency: 'INR',
  );

  /// Get fee configuration from Firestore or return default
  Future<FeeConfiguration> getFeeConfiguration() async {
    try {
      final doc = await _db.collection('config').doc('fees').get();
      if (doc.exists) {
        return FeeConfiguration.fromMap(doc.data()!);
      }
    } catch (e) {
      // Return default on error
    }
    return defaultFee;
  }

  /// Save fee configuration to Firestore
  Future<void> saveFeeConfiguration(FeeConfiguration config) async {
    await _db.collection('config').doc('fees').set(config.toMap());
  }

  /// Get current month in YYYY-MM format
  String getCurrentMonth() {
    return DateFormat('yyyy-MM').format(DateTime.now());
  }

  /// Check if a member has paid for the current month
  bool hasPaidCurrentMonth(UserModel member) {
    final currentMonth = getCurrentMonth();
    return member.lastPaymentMonth == currentMonth;
  }

  /// Check if a member's fee is overdue (past due date and not paid)
  bool isFeeOverdue(UserModel member, FeeConfiguration config) {
    if (hasPaidCurrentMonth(member)) return false;
    return DateTime.now().day > config.dueDay;
  }

  /// Get MemberFeeStatus for a user
  MemberFeeStatus getMemberFeeStatus(UserModel member, FeeConfiguration config) {
    final isPaid = hasPaidCurrentMonth(member);
    final isOverdue = !isPaid && DateTime.now().day > config.dueDay;

    return MemberFeeStatus(
      memberId: member.uid,
      memberName: member.name,
      membershipId: member.membershipId,
      phone: member.phone,
      lastPaymentMonth: member.lastPaymentMonth,
      isPaidCurrentMonth: isPaid,
      isOverdue: isOverdue,
      lastPaymentDate: member.lastPaymentDate,
    );
  }

  /// Stream of all members who haven't paid for current month
  Stream<List<UserModel>> getUnpaidMembers() {
    final currentMonth = getCurrentMonth();
    
    return _db.collection('users')
        .where('role', isEqualTo: 'member')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => UserModel.fromMap(doc.data()))
              .where((member) => member.lastPaymentMonth != currentMonth)
              .toList();
        });
  }

  /// Get list of unpaid members (one-time fetch)
  Future<List<UserModel>> getUnpaidMembersList() async {
    final currentMonth = getCurrentMonth();
    
    final snapshot = await _db.collection('users')
        .where('role', isEqualTo: 'member')
        .get();

    return snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data()))
        .where((member) => member.lastPaymentMonth != currentMonth)
        .toList();
  }

  /// Get count of unpaid members
  Future<int> getUnpaidMembersCount() async {
    final unpaidMembers = await getUnpaidMembersList();
    return unpaidMembers.length;
  }

  /// Store FCM token for a user (for push notifications)
  Future<void> storeFcmToken(String userId, String token) async {
    await _db.collection('users').doc(userId).update({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get FCM tokens for all unpaid members
  Future<List<String>> getUnpaidMembersFcmTokens() async {
    final unpaidMembers = await getUnpaidMembersList();
    final tokens = <String>[];
    
    for (final member in unpaidMembers) {
      final doc = await _db.collection('users').doc(member.uid).get();
      final token = doc.data()?['fcmToken'] as String?;
      if (token != null && token.isNotEmpty) {
        tokens.add(token);
      }
    }
    
    return tokens;
  }
}
