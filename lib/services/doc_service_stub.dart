import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import '../models/petition_model.dart';

/// Implementation for mobile platforms (Android/iOS)
Future<void> exportToDocImpl(PetitionModel data) async {
  final content = _generateHtmlContent(data);
  
  try {
    // Get temporary directory
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/Petition_${DateTime.now().millisecondsSinceEpoch}.doc');
    
    // Write content to temporary file first
    await file.writeAsString(content);

    // Prompt user to save the file using system dialog
    final params = SaveFileDialogParams(sourceFilePath: file.path);
    final filePath = await FlutterFileDialog.saveFile(params: params);

    if (filePath != null) {
      // Success case
      // Optional: Add a toast or snackbar here if context is available
    }
  } catch (e) {
    throw Exception('Failed to export Word document: $e');
  }
}

String _generateHtmlContent(PetitionModel data) {
  // Pre-compute attachment list HTML
  String attachmentListHtml = '';
  if (data.attachments.isNotEmpty) {
    final attLines = data.attachments.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final attItems = attLines.asMap().entries.map((e) => '<li>${e.key + 1}. ${e.value}</li>').join('');
    attachmentListHtml = '<div class="section"><p class="bold">இணைப்பு:</p><ul>$attItems</ul></div>';
  }

  // Word-specific HTML headers to ensure proper opening
  return """
<html xmlns:o='urn:schemas-microsoft-com:office:office' xmlns:w='urn:schemas-microsoft-com:office:word' xmlns='http://www.w3.org/TR/REC-html40'>
<head>
  <meta charset='utf-8'>
  <title>Petition</title>
  <style>
    body { font-family: 'Noto Sans Tamil', 'Arial Unicode MS', sans-serif; line-height: 1.6; padding: 40px; }
    .center { text-align: center; }
    .bold { font-weight: bold; }
    .underline { text-decoration: underline; }
    .section { margin-top: 25px; }
    .footer { margin-top: 40px; }
    table { width: 100%; }
    .signature-table td { width: 50%; vertical-align: top; }
    .highlight { background-color: #FFFF00; mso-highlight: yellow; font-weight: bold; color: black; }
    .org-name { color: black; font-weight: bold; text-decoration: none; }
  </style>
</head>
<body>
  <div class="center">
    <h2 class="underline highlight" style="font-size: 18px;">${_highlightLegalText(data.title)}</h2>
  </div>

  <div class="section">
    <p class="bold">அனுப்புநர்:</p>
    <div style="padding-left: 20px;">
      <p class="bold">${data.senderName}</p>
      ${data.senderDesignation.isNotEmpty ? '<p class="bold">${data.senderDesignation}</p>' : ''}
      <p>${data.senderAddress}</p>
      <p>தொலைபேசி: ${data.senderMobile}</p>
    </div>
  </div>

  <div class="section">
    <p class="bold">பெறுநர்:</p>
    <div style="padding-left: 20px;">
      <p class="bold">${data.recipientName}</p>
      ${data.recipientDesignation.isNotEmpty ? '<p class="bold">${data.recipientDesignation}</p>' : ''}
      <p>${data.recipientAddress}</p>
    </div>
  </div>

  <div class="section">
    <p><span class="bold highlight">பார்வை: ${_highlightLegalText(data.subject)}</span></p>
  </div>

  <div class="section">
    ${_highlightLegalText(data.content).split('\n').map((p) => '<p>$p</p>').join('')}
  </div>

  ${data.reqDocuments.isNotEmpty ? """
  <div class="section">
    <p class="bold">தேவைப்படும் ஆவணங்கள்:</p>
    <ul>
      ${data.reqDocuments.split('\n').where((l) => l.trim().isNotEmpty).map((l) => '<li>$l</li>').join('')}
    </ul>
  </div>
  <div class="section">
    <p>மேற்கண்ட ஆவணங்களை சான்றிட்ட நகலாக வழங்குமாறு கேட்டுக்கொள்கிறேன்.</p>
  </div>
  """ : ""}

  <div class="footer">
    <table class="signature-table">
      <tr>
        <td>
          <p>நாள்: ${data.date}</p>
          <p>இடம்: ${data.place}</p>
        </td>
        <td style="text-align: right;">
          <p class="bold">தங்கள் உண்மையுள்ள,</p>
          <br><br>
          <p>(${data.senderName})</p>
          <p class="bold" style="font-size: 16px;">மனுதாரர் கையொப்பம்</p>
        </td>
      </tr>
    </table>
  </div>

  $attachmentListHtml

  ${data.copyRecipients.isNotEmpty ? """
  <div class="section">
    <p class="bold">நகல் சமர்ப்பிக்கப்படுகிறது:</p>
    <p>${data.copyRecipients.replaceAll('\n', '<br>')}</p>
  </div>
  """ : ""}
</body>
</html>
""";
}

/// Helper to wrap legal keywords in highlight class
String _highlightLegalText(String text) {
  if (text.isEmpty) return text;
  
  // Keywords to highlight (Yellow)
  final yellowKeywords = [
    'பாரதிய சாட்சிய அதினியம், 2023',
    'பாரதிய சாட்சிய அதினியம் 2023',
    'பாரதிய சாட்சிய அதினியம்',
    'பிரிவு [\\d\\(\\)]+',
    'பிரிவு [\\d\\-\\s\\,]+ன் படி',
    'சான்று நகல் வேண்டி',
    'விண்ணப்பம்',
    'அரசாணை எண்.73/2018',
    'நாள்.11.06.2018',
    'W. P. No. 20527 /2014',
    'M. P. No. 1/2014',
    'நாள்.01.08.2014',
    'இந்திய அரசியல் அமைப்பு சட்டம் 1950',
    '14 வது பிரிவு',
    'தமிழ்நாடு அரசு குடிமை பணி விதிகள் 17 \\(2\\)',
    'அரசு ஊழியர் நடத்தை விதிகள் \\- 1975',
    '20வது பிரிவு',
    'பாரதிய நியாய சன்ஹிதா, 2023 பிரிவு 199',
    'பாரதிய சாக்ஷ்ய அதிநியம், 2023 பிரிவு 109',
    'ரூ.10 இலட்சம்',
    'மனித உரிமை பாதுகாப்பு சட்டம் \\- 1993',
    'நுகர்வோர் பாதுகாப்பு சட்டம் \\- 1986',
    'பிரிவு 12',
  ];

  String highlightedText = text;
  for (var pattern in yellowKeywords) {
    highlightedText = highlightedText.replaceAllMapped(
      RegExp(pattern), 
      (match) => '<span class="highlight">${match.group(0)}</span>'
    );
  }

  // Keywords to underline (Red)
  final redKeywords = [
    'நீதியைத்தேடி சட்ட விழிப்புணர்வு சங்கம்',
    'நீதியைத்தேடி சட்ட விழிப்புணர்வு சங்கத்தில்',
  ];

  for (var pattern in redKeywords) {
    highlightedText = highlightedText.replaceAllMapped(
      RegExp(pattern), 
      (match) => '<span class="org-name">${match.group(0)}</span>'
    );
  }
  
  return highlightedText;
}
