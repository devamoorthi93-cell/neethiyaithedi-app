import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import '../models/user_model.dart';
import '../models/payment_model.dart';
import '../models/membership_request_model.dart';
import '../models/petition_record_model.dart';
import '../models/donation_model.dart';

abstract class FirebaseService {
  Stream<User?> get authStateChanges;
  User? get currentUser;
  Future<UserModel?> getUserData(String uid);
  Stream<UserModel?> streamUserData(String uid);
  Future<void> saveUserData(UserModel user);
  Future<String> generateMembershipId();
  Future<void> recordPayment(PaymentModel payment);
  Stream<List<PaymentModel>> getUserPaymentHistory(String uid);
  Future<UserModel?> loginAdmin(String email, String password);
  Future<UserModel?> loginMember(String email, String password);
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
    String? bloodGroup,
    String? address,
    String feeCategory = 'paid',
  });
  Future<void> sendMagicLink(String email);
  Stream<List<UserModel>> getAllMembers();
  Stream<List<UserModel>> getAllAdmins();
  Future<void> deleteUser(String uid);
  Future<void> signOut();
  Future<void> submitMembershipRequest(Map<String, dynamic> requestData);
  Stream<List<MembershipRequestModel>> getAllMembershipRequests();
  Future<void> updateRequestStatus(String requestId, RequestStatus status);
  Future<void> deleteMembershipRequest(String requestId);
  Future<void> updateUserRole(String uid, UserRole role);
  Future<String> uploadFile(String path, Uint8List data, String fileName);
  Future<void> changePassword(String newPassword);
  Future<void> savePetitionRecord(PetitionRecord record);
  Stream<List<PetitionRecord>> getPetitionHistory();
  Stream<List<PetitionRecord>> getUserPetitionHistory(String uid);
  Future<void> recordOfflinePayment(String uid, double amount, String month);
  Future<void> setMeetConfig(String url, bool isActive);
  Stream<Map<String, dynamic>?> streamMeetConfig();
  Future<void> sendManualReminder(String uid);
  Stream<List<Map<String, dynamic>>> streamNotificationLogs();
  Future<void> recordDonation(DonationRecord donation);
  Stream<List<DonationRecord>> streamUserDonations(String uid);
  Stream<List<DonationRecord>> streamAllDonations();
  Future<void> updateUserDeviceToken(String token);
  Future<void> sendBroadcastNotification(String title, String body);
  Future<void> updateUserAccess(String uid, String accessType);
}

class RealFirebaseService implements FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  
  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<UserModel?> getUserData(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data()!);
    }
    return null;
  }

  @override
  Stream<UserModel?> streamUserData(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!);
      }
      return null;
    });
  }

  @override
  Future<void> saveUserData(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap(), SetOptions(merge: true));
  }

  @override
  Future<String> generateMembershipId() async {
    final year = DateTime.now().year.toString();
    final counterRef = _db.collection('config').doc('counters');
    
    return await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);
      
      int currentCount = 1;
      if (snapshot.exists) {
        currentCount = (snapshot.data()?['membership_count'] ?? 0) + 1;
      }
      
      transaction.set(counterRef, {'membership_count': currentCount}, SetOptions(merge: true));
      
      final sequence = currentCount.toString().padLeft(4, '0');
      return 'NT-$year-$sequence';
    });
  }

  @override
  Future<void> recordPayment(PaymentModel payment) async {
    await _db.collection('payments').doc(payment.paymentId).set(payment.toMap());
    
    if (payment.status == PaymentStatus.success) {
      await _db.collection('users').doc(payment.userId).update({
        'status': MembershipStatus.active.name,
        'lastPaymentMonth': payment.month,
        'lastPaymentDate': Timestamp.fromDate(payment.timestamp),
        'totalPaid': FieldValue.increment(payment.amount),
      });
    }
  }

  @override
  Stream<List<PaymentModel>> getUserPaymentHistory(String uid) {
    return _db.collection('payments')
        .where('userId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => PaymentModel.fromMap(doc.data())).toList());
  }

  @override
  Stream<List<UserModel>> getAllMembers() {
    return _db.collection('users')
        .where('role', isEqualTo: UserRole.member.name)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList());
  }

  @override
  Stream<List<UserModel>> getAllAdmins() {
    return _db.collection('users')
        .where('role', isEqualTo: UserRole.admin.name)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => UserModel.fromMap(doc.data())).toList());
  }

  @override
  Future<UserModel?> loginAdmin(String email, String password) async {
    final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    if (userCredential.user != null) {
      return await getUserData(userCredential.user!.uid);
    }
    return null;
  }

  @override
  Future<UserModel?> loginMember(String email, String password) async {
    final userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    if (userCredential.user != null) {
      return await getUserData(userCredential.user!.uid);
    }
    return null;
  }

  @override
  Future<void> sendMagicLink(String email) async {
    var acs = ActionCodeSettings(
        url: 'https://neethiyaithedi.page.link/login',
        handleCodeInApp: true,
        iOSBundleId: 'com.neethiyaithedi.app',
        androidPackageName: 'com.neethiyaithedi.app',
        androidInstallApp: true,
        androidMinimumVersion: '12');

    await _auth.sendSignInLinkToEmail(email: email, actionCodeSettings: acs);
  }

  @override
  Future<void> deleteUser(String uid) async {
    await _db.collection('users').doc(uid).delete();
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
  }

  @override
  Future<void> submitMembershipRequest(Map<String, dynamic> requestData) async {
    await _db.collection('membership_requests').add({
      ...requestData,
      'status': 'pending',
      'requestedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<List<MembershipRequestModel>> getAllMembershipRequests() {
    return _db.collection('membership_requests')
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => 
            MembershipRequestModel.fromMap(doc.id, doc.data())).toList());
  }

  @override
  Future<void> updateRequestStatus(String requestId, RequestStatus status) async {
    await _db.collection('membership_requests').doc(requestId).update({
      'status': status.name,
    });

    // Trigger notification for status change
    final requestDoc = await _db.collection('membership_requests').doc(requestId).get();
    final phone = requestDoc.data()?['phone'] as String?;
    
    if (phone != null) {
      // Find user with this phone to get their FCM token
      final userSnapshot = await _db.collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
          
      if (userSnapshot.docs.isNotEmpty) {
        final userData = userSnapshot.docs.first.data();
        final fcmToken = userData['fcmToken'] as String?;
        if (fcmToken != null) {
          await _db.collection('notification_triggers').add({
            'userId': userData['uid'],
            'fcmToken': fcmToken,
            'type': 'STATUS_UPDATE',
            'title': 'Request ${status.name.toUpperCase()}',
            'body': 'Your membership request has been ${status.name}.',
            'timestamp': FieldValue.serverTimestamp(),
          });
        }
      }
    }
  }

  @override
  Future<void> deleteMembershipRequest(String requestId) async {
    await _db.collection('membership_requests').doc(requestId).delete();
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
    String? bloodGroup,
    String? address,
    String feeCategory = 'paid',
  }) async {
    FirebaseApp secondaryApp = await Firebase.initializeApp(
      name: 'SecondaryApp',
      options: Firebase.app().options,
    );
    
    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final userCredential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final uid = userCredential.user!.uid;
      
      // Save data to Firestore using the primary app's instance
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role.name,
        'membershipId': membershipId,
        'joinDate': FieldValue.serverTimestamp(),
        'status': MembershipStatus.active.name,
        'totalPaid': 0.0,
        'aadhaarNo': aadhaarNo,
        'aadhaarFrontUrl': aadhaarFrontUrl,
        'aadhaarBackUrl': aadhaarBackUrl,
        'gender': gender,
        'bloodGroup': bloodGroup,
        'address': address,
        'feeCategory': feeCategory,
      });

      await secondaryAuth.signOut();
    } catch (e) {
      throw Exception('Failed to create account: $e');
    } finally {
      await secondaryApp.delete();
    }
  }

  @override
  Future<void> updateUserRole(String uid, UserRole role) async {
    await _db.collection('users').doc(uid).update({
      'role': role.name,
    });
  }

  @override
  Future<String> uploadFile(String path, Uint8List data, String fileName) async {
    final ref = _storage.ref().child(path).child(fileName);
    final uploadTask = ref.putData(data);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  @override
  Future<void> changePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updatePassword(newPassword);
    } else {
      throw FirebaseAuthException(code: 'no-current-user', message: 'No user logged in');
    }
  }

  @override
  Future<void> savePetitionRecord(PetitionRecord record) async {
    await _db.collection('petitions').add(record.toMap());
    await _db.collection('users').doc(record.userId).update({
      'petitionCount': FieldValue.increment(1),
    });
  }

  @override
  Stream<List<PetitionRecord>> getPetitionHistory() {
    return _db.collection('petitions')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => 
            PetitionRecord.fromMap(doc.id, doc.data())).toList());
  }

  @override
  Stream<List<PetitionRecord>> getUserPetitionHistory(String uid) {
    return _db.collection('petitions')
        .where('userId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => 
            PetitionRecord.fromMap(doc.id, doc.data())).toList());
  }

  @override
  Future<void> recordOfflinePayment(String uid, double amount, String month) async {
    final paymentId = 'OFFLINE_${DateTime.now().millisecondsSinceEpoch}';
    final payment = PaymentModel(
      paymentId: paymentId,
      userId: uid,
      amount: amount,
      month: month,
      timestamp: DateTime.now(),
      status: PaymentStatus.success,
      method: 'Offline/Cash',
    );
    
    await recordPayment(payment);
  }

  @override
  Future<void> setMeetConfig(String url, bool isActive) async {
    await _db.collection('config').doc('meet').set({
      'url': url,
      'active': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<Map<String, dynamic>?> streamMeetConfig() {
    return _db.collection('config').doc('meet').snapshots().map((doc) {
      if (doc.exists) {
        return doc.data();
      }
      return null;
    });
  }

  @override
  Future<void> sendManualReminder(String uid) async {
    final userDoc = await _db.collection('users').doc(uid).get();
    final userData = userDoc.data();
    final fcmToken = userData?['fcmToken'] as String?;

    if (fcmToken == null || fcmToken.isEmpty) {
      // Log failure in Firestore
      await _db.collection('notifications_log').add({
        'userId': uid,
        'userName': userData?['name'] ?? 'Unknown',
        'type': 'MANUAL_REMINDER',
        'status': 'failed',
        'error': 'No FCM token found',
        'sentAt': FieldValue.serverTimestamp(),
      });
      throw Exception('User has no active notification token');
    }

    try {
      // Trigger a Cloud Function or send via Admin SDK (if possible from client, but usually restricted)
      // Since we are on client-side Flutter, we usually use a "triggers" collection or call an HTTPS function.
      // Based on index.js, there is triggerFeeReminders but it's for all.
      // Let's implement a specific trigger for one user.
      
      await _db.collection('notification_triggers').add({
        'userId': uid,
        'fcmToken': fcmToken,
        'type': 'MANUAL_REMINDER',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Log success (tentative, Cloud Function will finalize)
      await _db.collection('notifications_log').add({
        'userId': uid,
        'userName': userData?['name'] ?? 'Unknown',
        'type': 'MANUAL_REMINDER',
        'status': 'sent',
        'sentAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      await _db.collection('notifications_log').add({
        'userId': uid,
        'userName': userData?['name'] ?? 'Unknown',
        'type': 'MANUAL_REMINDER',
        'status': 'failed',
        'error': e.toString(),
        'sentAt': FieldValue.serverTimestamp(),
      });
      rethrow;
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> streamNotificationLogs() {
    return _db.collection('notifications_log')
        .orderBy('sentAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {
          ...doc.data(),
          'id': doc.id,
        }).toList());
  }

  @override
  Future<void> recordDonation(DonationRecord donation) async {
    await _db.collection('donations').add(donation.toMap());
  }

  @override
  Stream<List<DonationRecord>> streamUserDonations(String uid) {
    return _db.collection('donations')
        .where('userId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DonationRecord.fromMap(doc.id, doc.data()))
            .toList());
  }

  @override
  Stream<List<DonationRecord>> streamAllDonations() {
    return _db.collection('donations')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DonationRecord.fromMap(doc.id, doc.data()))
            .toList());
  }

  @override
  Future<void> updateUserDeviceToken(String token) async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _db.collection('users').doc(uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Future<void> sendBroadcastNotification(String title, String body) async {
    await _db.collection('notification_triggers').add({
      'type': 'BROADCAST',
      'title': title,
      'body': body,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Log the broadcast
    await _db.collection('notifications_log').add({
      'userId': 'GLOBAL',
      'userName': 'All Members',
      'type': 'BROADCAST',
      'title': title,
      'status': 'sent',
      'sentAt': FieldValue.serverTimestamp(),
    });
  }
  @override
  Future<void> updateUserAccess(String uid, String accessType) async {
    await _db.collection('users').doc(uid).update({'feeCategory': accessType});
  }
}
