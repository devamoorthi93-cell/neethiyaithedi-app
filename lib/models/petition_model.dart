
class PetitionModel {
  final String senderName;
  final String senderDesignation; // e.g., State General Secretary
  final String senderAddress;
  final String senderMobile;
  
  final String recipientName;
  final String recipientDesignation;
  final String recipientAddress;

  final String title;
  final String subject; // Parvai
  final String content; // Body
  final String reqDocuments; // Thevaipadum Aavanangal
  final String attachments; // Inaippu
  
  final String place;
  final String date;
  final String copyRecipients; // நகல் சமர்ப்பிக்கப்படுகிறது:
  
  // Extra fields from Enhanced model
  final String? applicationNumber;
  final String? referenceNumber;
  final List<String>? supportingDocs;
  final String? urgencyLevel; // Normal, Urgent, Immediate

  PetitionModel({
    required this.senderName,
    required this.senderDesignation,
    required this.senderAddress,
    required this.senderMobile,
    required this.recipientName,
    required this.recipientDesignation,
    required this.recipientAddress,
    required this.title,
    required this.subject,
    required this.content,
    required this.reqDocuments,
    required this.attachments,
    required this.place,
    required this.date,
    this.copyRecipients = '',
    this.applicationNumber,
    this.referenceNumber,
    this.supportingDocs,
    this.urgencyLevel = 'Normal',
  });
}
