import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { admin, member }

enum MembershipStatus { active, inactive }

class UserModel {
  final String uid;
  final String name;
  final String phone;
  final String email;
  final UserRole role; // Enum
  final String? membershipId;
  final String? password;
  final String? address;
  final DateTime joinDate;
  final MembershipStatus status;
  final String? profileImageUrl;
  final String? lastPaymentMonth;
  final double totalPaid;
  final String? aadhaarNo;
  final String? aadhaarFrontUrl;
  final String? aadhaarBackUrl;
  final String? gender;
  final String? bloodGroup;
  final DateTime? lastPaymentDate;
  final int petitionCount;
  
  // New Fields
  final String? fcmToken;
  final bool isApproved;
  final String? panNumber;
  final String feeCategory; // 'all_free', 'petition_free', 'membership_free', 'paid'
  final String? designation; // Custom designation (optional)

  // Helper getters
  bool get isMembershipFree => feeCategory == 'all_free' || feeCategory == 'membership_free';
  bool get isPetitionFree => feeCategory == 'all_free' || feeCategory == 'petition_free';

  UserModel({
    required this.uid,
    required this.name,
    required this.phone,
    required this.email,
    this.role = UserRole.member, // Default to Enum value
    this.membershipId,
    this.password,
    this.address,
    required this.joinDate,
    required this.status,
    this.profileImageUrl,
    this.lastPaymentMonth,
    this.totalPaid = 0.0,
    this.aadhaarNo,
    this.aadhaarFrontUrl,
    this.aadhaarBackUrl,
    this.gender,
    this.bloodGroup,
    this.lastPaymentDate,
    this.petitionCount = 0,
    this.fcmToken,
    this.isApproved = false,
    this.panNumber,
    this.feeCategory = 'paid',
    this.designation,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => UserRole.member,
      ),
      membershipId: map['membershipId'],
      password: map['password'],
      address: map['address'],
      joinDate: map['joinDate'] != null 
          ? (map['joinDate'] as Timestamp).toDate() 
          : DateTime.now(),
      status: MembershipStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => MembershipStatus.inactive,
      ),
      profileImageUrl: map['profileImageUrl'],
      lastPaymentMonth: map['lastPaymentMonth'],
      totalPaid: (map['totalPaid'] ?? 0.0).toDouble(),
      aadhaarNo: map['aadhaarNo'],
      aadhaarFrontUrl: map['aadhaarFrontUrl'],
      aadhaarBackUrl: map['aadhaarBackUrl'],
      gender: map['gender'],
      bloodGroup: map['bloodGroup'],
      lastPaymentDate: map['lastPaymentDate'] != null 
          ? (map['lastPaymentDate'] as Timestamp).toDate() 
          : null,
      petitionCount: map['petitionCount'] ?? 0,
      fcmToken: map['fcmToken'],
      isApproved: map['isApproved'] ?? false,
      panNumber: map['panNumber'],
      feeCategory: map['feeCategory'] ?? (map['freeAccessType'] == 'all' ? 'all_free' : 'paid'),
      designation: map['designation'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'phone': phone,
      'email': email,
      'role': role.name,
      'membershipId': membershipId,
      'password': password,
      'address': address,
      'joinDate': Timestamp.fromDate(joinDate),
      'status': status.name,
      'profileImageUrl': profileImageUrl,
      'lastPaymentMonth': lastPaymentMonth,
      'totalPaid': totalPaid,
      'aadhaarNo': aadhaarNo,
      'aadhaarFrontUrl': aadhaarFrontUrl,
      'aadhaarBackUrl': aadhaarBackUrl,
      'gender': gender,
      'bloodGroup': bloodGroup,
      'lastPaymentDate': lastPaymentDate != null ? Timestamp.fromDate(lastPaymentDate!) : null,
      'petitionCount': petitionCount,
      'fcmToken': fcmToken,
      'isApproved': isApproved,
      'panNumber': panNumber,
      'feeCategory': feeCategory,
      'designation': designation,
    };
  }

  UserModel copyWith({
    String? name,
    String? phone,
    String? email,
    UserRole? role,
    String? membershipId,
    String? password,
    String? address,
    DateTime? joinDate,
    MembershipStatus? status,
    String? profileImageUrl,
    String? lastPaymentMonth,
    double? totalPaid,
    String? aadhaarNo,
    String? aadhaarFrontUrl,
    String? aadhaarBackUrl,
    String? gender,
    String? bloodGroup,
    DateTime? lastPaymentDate,
    int? petitionCount,
    String? fcmToken,
    bool? isApproved,
    String? panNumber,
    String? feeCategory,
    String? designation,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      membershipId: membershipId ?? this.membershipId,
      password: password ?? this.password,
      address: address ?? this.address,
      joinDate: joinDate ?? this.joinDate,
      status: status ?? this.status,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      lastPaymentMonth: lastPaymentMonth ?? this.lastPaymentMonth,
      totalPaid: totalPaid ?? this.totalPaid,
      aadhaarNo: aadhaarNo ?? this.aadhaarNo,
      aadhaarFrontUrl: aadhaarFrontUrl ?? this.aadhaarFrontUrl,
      aadhaarBackUrl: aadhaarBackUrl ?? this.aadhaarBackUrl,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
      petitionCount: petitionCount ?? this.petitionCount,
      fcmToken: fcmToken ?? this.fcmToken,
      isApproved: isApproved ?? this.isApproved,
      panNumber: panNumber ?? this.panNumber,
      feeCategory: feeCategory ?? this.feeCategory,
      designation: designation ?? this.designation,
    );
  }
}
