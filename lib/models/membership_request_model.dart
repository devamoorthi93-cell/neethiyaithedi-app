import 'package:cloud_firestore/cloud_firestore.dart';

enum RequestStatus { pending, approved, rejected }

class MembershipRequestModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String aadhaarNo;
  final String? aadhaarFrontUrl;
  final String? aadhaarBackUrl;
  final String? gender;
  final String? bloodGroup;
  final RequestStatus status;
  final DateTime requestedAt;

  MembershipRequestModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    required this.aadhaarNo,
    this.aadhaarFrontUrl,
    this.aadhaarBackUrl,
    this.gender,
    this.bloodGroup,
    required this.status,
    required this.requestedAt,
  });

  factory MembershipRequestModel.fromMap(String id, Map<String, dynamic> map) {
    return MembershipRequestModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      aadhaarNo: map['aadhaarNo'] ?? '',
      aadhaarFrontUrl: map['aadhaarFrontUrl'],
      aadhaarBackUrl: map['aadhaarBackUrl'],
      gender: map['gender'],
      bloodGroup: map['bloodGroup'],
      status: RequestStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => RequestStatus.pending,
      ),
      requestedAt: map['requestedAt'] != null 
          ? (map['requestedAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'aadhaarNo': aadhaarNo,
      'aadhaarFrontUrl': aadhaarFrontUrl,
      'aadhaarBackUrl': aadhaarBackUrl,
      'gender': gender,
      'bloodGroup': bloodGroup,
      'status': status.name,
      'requestedAt': Timestamp.fromDate(requestedAt),
    };
  }
}
