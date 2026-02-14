import 'package:cloud_firestore/cloud_firestore.dart';

class PetitionRecord {
  final String id;
  final String userId;
  final String userName;
  final String petitionType;
  final String title;
  final String subject;
  final String content;
  final DateTime timestamp;

  PetitionRecord({
    required this.id,
    required this.userId,
    required this.userName,
    required this.petitionType,
    required this.title,
    required this.subject,
    required this.content,
    required this.timestamp,
  });

  factory PetitionRecord.fromMap(String id, Map<String, dynamic> map) {
    return PetitionRecord(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      petitionType: map['petitionType'] ?? '',
      title: map['title'] ?? '',
      subject: map['subject'] ?? '',
      content: map['content'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'petitionType': petitionType,
      'title': title,
      'subject': subject,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
