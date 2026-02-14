import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/payment_model.dart';
import '../models/membership_request_model.dart';
import '../models/petition_record_model.dart';
import '../models/donation_model.dart';
import 'firebase_service.dart';

class MockFirebaseService implements FirebaseService {
  final _authStateController = StreamController<User?>.broadcast();
  final _users = <String, UserModel>{};
  final _payments = <String, List<PaymentModel>>{};
  final _membersController = StreamController<List<UserModel>>.broadcast();

  MockFirebaseService() {
    // Inject mock admin for testing
    final admin = UserModel(
      uid: 'admin_123',
      name: 'System Admin',
      phone: '9999999999',
      email: 'admin@neethiyaithedi.com',
      password: 'admin123',
      role: UserRole.admin,
      membershipId: 'NT-2024-0000',
      joinDate: DateTime.now(),
      status: MembershipStatus.active,
      totalPaid: 0,
    );
    _users[admin.uid] = admin;

    // Inject mock member
    final member = UserModel(
      uid: 'member_123',
      name: 'John Doe',
      phone: '1234567890',
      email: 'john@example.com',
      password: 'member123',
      role: UserRole.member,
      membershipId: 'NT-2024-0001',
      joinDate: DateTime.now().subtract(const Duration(days: 30)),
      status: MembershipStatus.active,
      lastPaymentMonth: '2024-01',
      totalPaid: 100,
    );
    _users[member.uid] = member;
    
    // Initialize members stream
    final initialMembers = _users.values.where((m) => m.role == UserRole.member).toList();
    _membersController.add(initialMembers);
  }

  // --- New Auth Methods for Simulation ---

  @override
  Future<UserModel?> loginAdmin(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    final admin = _users.values.firstWhere(
      (u) => u.role == UserRole.admin && u.email == email && u.password == password,
      orElse: () => throw Exception('Invalid Admin Credentials'),
    );
    _authStateController.add(null); // Simulated state
    return admin;
  }

  @override
  Future<UserModel?> loginMember(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    final member = _users.values.firstWhere(
      (u) => u.role == UserRole.member && u.email == email && u.password == password,
      orElse: () => throw Exception('Invalid Member Credentials'),
    );
    _authStateController.add(null); // Simulated state
    return member;
  }

  @override
  Future<void> sendMagicLink(String email) async {
    await Future.delayed(const Duration(seconds: 1));
    print('Simulated Magic Link sent to $email');
  }

  // --- End New Auth Methods ---

  @override
  Stream<User?> get authStateChanges => _authStateController.stream;

  @override
  User? get currentUser => null; // Simplified for mock

  @override
  Future<UserModel?> getUserData(String uid) async {
    return _users[uid];
  }

  @override
  Stream<UserModel?> streamUserData(String uid) {
    return Stream.value(_users[uid]);
  }

  @override
  Future<void> saveUserData(UserModel user) async {
    _users[user.uid] = user;
  }

  @override
  Future<String> generateMembershipId() async {
    return 'NT-2024-${_users.length.toString().padLeft(4, '0')}';
  }

  @override
  Future<void> recordPayment(PaymentModel payment) async {
    final list = _payments[payment.userId] ?? [];
    list.add(payment);
    _payments[payment.userId] = list;
    
    if (payment.status == PaymentStatus.success) {
      final user = _users[payment.userId];
      if (user != null) {
        _users[payment.userId] = user.copyWith(
          status: MembershipStatus.active,
          lastPaymentMonth: payment.month,
          totalPaid: user.totalPaid + payment.amount,
        );
      }
    }
  }

  @override
  Stream<List<PaymentModel>> getUserPaymentHistory(String uid) {
    return Stream.value(_payments[uid] ?? []);
  }

  @override
  Stream<List<UserModel>> getAllMembers() {
    return _membersController.stream;
  }

  @override
  Stream<List<UserModel>> getAllAdmins() {
    return Stream.value(_users.values.where((u) => u.role == UserRole.admin).toList());
  }

  @override
  Future<void> deleteUser(String uid) async {
    // Mock delete
    await Future.delayed(const Duration(milliseconds: 100)); // Simulate async operation
    _users.remove(uid);
    final updatedMembers = _users.values.where((m) => m.role == UserRole.member).toList();
    _membersController.add(updatedMembers);
  }

  @override
  Future<void> signOut() async {
    _authStateController.add(null);
  }

  @override
  Future<void> submitMembershipRequest(Map<String, dynamic> requestData) async {
    await Future.delayed(const Duration(seconds: 1));
    print('Simulated Request Submitted: $requestData');
  }

  @override
  Stream<List<MembershipRequestModel>> getAllMembershipRequests() {
    return Stream.value([
      MembershipRequestModel(
        id: 'req_1',
        name: 'Vimal Fotoz',
        email: 'vimal@example.com',
        phone: '9876543210',
        address: '123 Main St, Chennai',
        aadhaarNo: '123456789012',
        status: RequestStatus.pending,
        requestedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      MembershipRequestModel(
        id: 'req_2',
        name: 'Arun Kumar',
        email: 'arun@example.com',
        phone: '1234567890',
        address: '456 Side St, Madurai',
        aadhaarNo: '987654321098',
        status: RequestStatus.pending,
        requestedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ]);
  }

  @override
  Future<void> updateRequestStatus(String requestId, RequestStatus status) async {
    await Future.delayed(const Duration(milliseconds: 500));
    print('Mock Request Status Updated: $requestId -> $status');
  }

  @override
  Future<void> deleteMembershipRequest(String requestId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    print('Mock Request Deleted: $requestId');
  }

  @override
  Future<void> createAccount({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String membershipId,
    required UserRole role,
    String? aadhaarNo,
    String? aadhaarFrontUrl,
    String? aadhaarBackUrl,
    String? gender,
    String? gender,
    String? bloodGroup,
    String? feeCategory,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    print('Mock Account Created: $email with role $role');
    final newUser = UserModel(
      uid: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      email: email,
      phone: phone,
      membershipId: membershipId,
      role: role,
      joinDate: DateTime.now(),
      status: MembershipStatus.active,
      aadhaarNo: aadhaarNo,
      aadhaarFrontUrl: aadhaarFrontUrl,
      aadhaarBackUrl: aadhaarBackUrl,
      gender: gender,
      bloodGroup: bloodGroup,
      feeCategory: feeCategory ?? 'paid',
    );
    _users[newUser.uid] = newUser;
    if (role == UserRole.member) {
      final updatedMembers = _users.values.where((m) => m.role == UserRole.member).toList();
      _membersController.add(updatedMembers);
    }
  }

  @override
  Future<void> updateUserAccess(String uid, String accessType) async {
    final user = _users[uid];
    if (user != null) {
      _users[uid] = user.copyWith(feeCategory: accessType);
    }
  }

  @override
  Future<void> updateUserRole(String uid, UserRole role) async {
    final user = _users[uid];
    if (user != null) {
      _users[uid] = user.copyWith(role: role);
    }
  }

  @override
  Future<String> uploadFile(String path, Uint8List data, String fileName) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return 'https://firebasestorage.googleapis.com/v0/b/mock/o/${Uri.encodeComponent('$path/$fileName')}?alt=media';
  }

  @override
  Future<void> changePassword(String newPassword) async {
    await Future.delayed(const Duration(seconds: 1));
    print('Mock password changed to: $newPassword');
  }

  // Helper for mock login
  void simulateLogin(String uid) {
    // We can't easily create a mock 'User' object from firebase_auth, 
    // so in simulation we might need to adjust the providers to handle UID directly.
    // For now, let's keep it simple and just trigger the stream.
  }

  @override
  Future<void> savePetitionRecord(PetitionRecord record) async {
    print('Mock Petition saved: ${record.petitionType}');
  }

  @override
  Stream<List<PetitionRecord>> getPetitionHistory() => Stream.value([]);

  @override
  Stream<List<PetitionRecord>> getUserPetitionHistory(String uid) => Stream.value([]);

  @override
  Future<void> recordOfflinePayment(String uid, double amount, String month) async {
    final user = _users[uid];
    if (user != null) {
      _users[uid] = user.copyWith(
        status: MembershipStatus.active,
        lastPaymentMonth: month,
        totalPaid: user.totalPaid + amount,
      );
    }
  }

  @override
  Future<void> setMeetConfig(String url, bool isActive) async {
    print('Mock Meet Config updated: $url, Active: $isActive');
  }

  @override
  Stream<Map<String, dynamic>?> streamMeetConfig() => Stream.value({
    'url': 'https://meet.google.com/mock-link',
    'active': true,
  });

  @override
  Future<void> sendManualReminder(String uid) async {
    print('Mock Reminder sent to $uid');
  }

  @override
  Stream<List<Map<String, dynamic>>> streamNotificationLogs() => Stream.value([]);

  @override
  Future<void> recordDonation(DonationRecord donation) async {
    print('Mock Donation recorded: ${donation.amount}');
  }

  @override
  Stream<List<DonationRecord>> streamUserDonations(String uid) => Stream.value([]);

  @override
  Stream<List<DonationRecord>> streamAllDonations() => Stream.value([]);

  @override
  Future<void> updateUserDeviceToken(String token) async {
    print('Mock Device Token updated: $token');
  }

  @override
  Future<void> sendBroadcastNotification(String title, String body) async {
    print('Mock Broadcast sent: $title - $body');
  }
}
