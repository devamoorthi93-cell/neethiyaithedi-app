import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/petition_model.dart';

import 'pdf_service_stub.dart'
    if (dart.library.html) 'pdf_service_web.dart' as web_impl;


class PetitionPdfService {
  // Cache for fonts
  static pw.Font? _tamilRegularFont;
  static pw.Font? _tamilBoldFont;
  static pw.Font? _fallbackFont;


  Future<List<int>> generatePetitionPdf(PetitionModel data) async {
    // 1. Generate HTML Content (Refined template for high quality)
    final htmlContent = _generateValidationHtml(data);

    // 2. WEB: Print directly
    if (kIsWeb) {
      await web_impl.printPdfWeb(htmlContent);
      return [];
    }
    
    // 3. MOBILE: Use Printing.convertHtml (Native WebView) for correct Tamil rendering
    try {
      final pdfBytes = await Printing.convertHtml(
        html: htmlContent,
        format: PdfPageFormat.a4,
      );
      return pdfBytes;
    } catch (e, stack) {
      debugPrint('Error generating PDF via Printing.convertHtml: $e');
      debugPrintStack(stackTrace: stack);
      rethrow;
    }
  }

  // Helper: Generate Full HTML for PDF
  String _generatePdfHtml(PetitionModel data) {
    // Pre-compute attachment list HTML for print preview
    String attListHtml = '';
    if (data.attachments.isNotEmpty) {
      final attLines = data.attachments.split('\n').where((l) => l.trim().isNotEmpty).toList();
      final attItems = attLines.asMap().entries.map((e) => '<li><span class="bold">${e.key + 1}. ${e.value}</span></li>').join('');
      attListHtml = '<div class="attachments"><div class="bold">இணைப்பு:</div><ul>$attItems</ul></div>';
    }

    return '''
      <!DOCTYPE html>
      <html lang="ta">
      <head>
        <meta charset="UTF-8">
        <style>
          @import url('https://fonts.googleapis.com/css2?family=Noto+Sans+Tamil:wght@400;700&display=swap');
          body { font-family: 'Noto Sans Tamil', sans-serif; padding: 30px; color: #000; line-height: 1.6; }
          .header { text-align: center; font-weight: 700; margin-bottom: 20px; text-decoration: underline; font-size: 18px; }
          .section { margin-bottom: 10px; }
          .bold { font-weight: 700; }
          .label { font-weight: 700; width: 100px; display: inline-block; }
          .content { text-align: justify; text-justify: inter-word; white-space: pre-wrap; }
          .footer { margin-top: 30px; display: flex; justify-content: space-between; }
          .signature { text-align: center; }
          .attachments { margin-top: 30px; }
          ul { padding-left: 20px; }
        </style>
      </head>
      <body>
        <div class="header">${_highlightLegalText(data.title)}</div>

        <div class="section">
          <div class="bold">அனுப்புநர்:</div>
          <div style="margin-left: 20px;">
            <div class="bold">${data.senderName}</div>
            ${data.senderDesignation.isNotEmpty ? '<div>${data.senderDesignation}</div>' : ''}
            <div>${data.senderAddress}</div>
            ${data.senderMobile.isNotEmpty ? '<div>தொலைபேசி: ${data.senderMobile}</div>' : ''}
          </div>
        </div>

        <div class="section">
          <div class="bold">பெறுநர்:</div>
          <div style="margin-left: 20px;">
            <div class="bold">${data.recipientName}</div>
            ${data.recipientDesignation.isNotEmpty ? '<div>${data.recipientDesignation}</div>' : ''}
            <div>${data.recipientAddress}</div>
          </div>
        </div>

        ${data.subject.isNotEmpty ? '''
        <div class="section">
          <span class="bold">பார்வை:</span> ${_highlightLegalText(data.subject)}
        </div>
        ''' : ''}

        <div class="section content">
          ${_highlightLegalText(data.content).replaceAll('\n', '<br>')}
        </div>


        ${data.reqDocuments.isNotEmpty ? '''
        <div class="section">
          <div class="bold">தேவைப்படும் ஆவணங்கள்:</div>
          <div style="margin-left: 20px;">
             ${data.reqDocuments.split('\n').where((l) => l.trim().isNotEmpty).toList().asMap().entries.map((e) => '<div class="bold">${e.key + 1}. ${e.value}</div>').join('')}
          </div>
        </div>
        <div class="section bold">மேற்கண்ட ஆவணங்களை சான்றிட்ட நகலாக வழங்குமாறு கேட்டுக்கொள்கிறேன்.</div>
        ''' : ''}

        <div class="footer">
          <div class="col">
            <div class="bold">இடம்: ${data.place}</div>
            <div class="bold">நாள்: ${data.date}</div>
          </div>
          <div class="col right" style="align-items: flex-end;">
            <div class="bold"> தங்கள் உண்மையுள்ள,</div>
            <div style="height: 40px;"></div>
            <div class="bold">(${data.senderName})</div>
            <div class="bold">மனுதாரர் கையொப்பம்</div>
          </div>
        </div>


        $attListHtml

        ${data.copyRecipients.trim().length > 5 ? '''
        <div class="section">
          <div class="bold">நகல் சமர்ப்பிக்கப்படுகிறது:</div>
          <div style="white-space: pre-wrap; margin-left: 20px;">${data.copyRecipients}</div>
        </div>
        ''' : ''}

      </body>
      </html>
    ''';
  }

  String _generateValidationHtml(PetitionModel data) {
    // Basic CSS for styling
    final css = """
      <style>
        @import url('https://fonts.googleapis.com/css2?family=Noto+Sans+Tamil:wght@400;700&display=swap');
        @page { size: A4; margin: 25mm 18mm; }
        body { 
          font-family: 'Noto Sans Tamil', 'Nirmala UI', sans-serif; 
          font-size: 13pt; 
          line-height: 1.7; 
          color: #000; 
          -webkit-font-smoothing: antialiased;
          text-rendering: optimizeLegibility;
        }
        .header { 
          text-align: center; 
          font-weight: 900; 
          text-decoration: underline; 
          font-size: 16pt; 
          margin-bottom: 30px; 
          color: #000; 
          text-transform: uppercase;
        }
        .section { margin-bottom: 15px; }
        .bold { font-weight: 700; color: #000; }
        .row { display: flex; justify-content: space-between; }
        .col { display: flex; flex-direction: column; }
        .right { text-align: right; }
        .highlight { font-weight: 700; color: #000; display: inline; padding: 0; background: none; }
        .content-body { 
          text-align: justify; 
          text-justify: inter-word; 
          margin-top: 20px; 
          margin-bottom: 20px;
          word-spacing: 1px;
        }
        .signature-box { margin-top: 50px; }
        .signature-name { margin-top: 40px; }
        ul { padding-left: 20px; margin: 10px 0; }
        ul li { list-style-type: none; margin-bottom: 6px; } 
      </style>
    """;

    // Required Documents list generation with numbering
    String reqDocsHtml = "";
    if (data.reqDocuments.isNotEmpty) {
      final docs = data.reqDocuments.split('\n').where((l) => l.trim().isNotEmpty).toList();
      reqDocsHtml += "<div class='section'><div class='bold'>தேவைப்படும் ஆவணங்கள்:</div><ul>";
      for (int i = 0; i < docs.length; i++) {
        String cleanItem = docs[i].trim().replaceFirst(RegExp(r'^[\d]+[\.\)\-\s]+'), '').trim();
        reqDocsHtml += "<li><span class='bold'>${i + 1}. $cleanItem</span></li>";
      }
      reqDocsHtml += "</ul></div>";
      // Concluding statement
      reqDocsHtml += "<div class='section'>மேற்கண்ட ஆவணங்களை சான்றிட்ட நகலாக வழங்குமாறு கேட்டுக்கொள்கிறேன்.</div>";
    }

    // Attachments section
    // Attachments section
    String attachmentsHtml = "";
    if (data.attachments.isNotEmpty) {
      final attList = data.attachments.split('\n').where((l) => l.trim().isNotEmpty).toList();
      attachmentsHtml = "<div class='section'><div class='bold'>இணைப்பு:</div><ul>";
      for (int i = 0; i < attList.length; i++) {
         attachmentsHtml += "<li><span class='bold'>${i + 1}. ${attList[i]}</span></li>";
      }
      attachmentsHtml += "</ul></div>";
    }

    // CC Section
    String ccHtml = "";
    if (data.copyRecipients.trim().isNotEmpty && data.copyRecipients.length > 5) {
      ccHtml = "<div class='section'><div class='bold'>நகல் சமர்ப்பிக்கப்படுகிறது:</div><div>${data.copyRecipients.replaceAll('\n', '<br>')}</div></div>";
    }

    // Subject Section
    String subjectHtml = "";
    if (data.subject.isNotEmpty) {
      subjectHtml = "<div class='section'><span class='bold highlight'>பார்வை: ${_highlightLegalText(data.subject)}</span></div>";
    }
    
    // Address format helper
    String formatAddress(String name, String designation, String address, String mobile) {
      String html = "<div class='bold'>$name</div>";
      if (designation.isNotEmpty) html += "<div class='bold'>$designation</div>";
      html += "<div>${address.replaceAll('\n', '<br>')}</div>";
      if (mobile.isNotEmpty) html += "<div>தொலைபேசி: $mobile</div>";
      return html;
    }

    return """
      <!DOCTYPE html>
      <html lang="ta">
      <head>
        <meta charset="UTF-8">
        <title>Petition</title>
        <link rel="preconnect" href="https://fonts.googleapis.com">
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
        <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+Tamil:wght@400;700&display=swap" rel="stylesheet">
        $css
      </head>
      <body>
        <div class="header"><span class="highlight">${_highlightLegalText(data.title)}</span></div>
        
        <div class="section">
          <div class="bold">அனுப்புநர்:</div>
          <div>${formatAddress(data.senderName, data.senderDesignation, data.senderAddress, data.senderMobile)}</div>
        </div>

        <div class="section">
          <div class="bold">பெறுநர்:</div>
          <div>${formatAddress(data.recipientName, data.recipientDesignation, data.recipientAddress, "")}</div>
        </div>

        $subjectHtml

        <div class="section content-body">
          ${_highlightLegalText(data.content).replaceAll('\n', '<br>')}
        </div>

        $reqDocsHtml

        <div class="section signature-box row">
          <div class="col">
            <div>நாள்: ${data.date}</div>
            <div>இடம்: ${data.place}</div>
          </div>
          <div class="col right">
            <div class="bold">தங்கள் உண்மையுள்ள,</div>
            <div class="signature-name">(${data.senderName})</div>
            <div style="font-size: 10pt;">மனுதாரர் கையொப்பம்</div>
          </div>
        </div>

        $attachmentsHtml
        
        $ccHtml
      </body>
      </html>
    """;
  }

  /// Helper to wrap legal keywords in highlight class
  String _highlightLegalText(String text) {
    if (text.isEmpty) return text;
    
    // Keywords to highlight (Yellow)
    final yellowKeywords = [
      'பாரதிய சாட்சிய அதினியம், 2023 பிரிவு [\\d\\(\\)\\s\\,\\-\\.\\u0B80-\\u0BFF]+(?:படி|கீழ்)', // Combined phrase
      'பாரதிய சாட்சிய அதினியம்[\\s]*2023 பிரிவு [\\d\\(\\)\\s\\,\\-\\.\\u0B80-\\u0BFF]+(?:படி|கீழ்)', // Combined phrase
      'பாரதிய சாட்சிய அதினியம், 2023',
      'பாரதிய சாட்சிய அதினியம்[\\s]*2023',
      'பாரதிய சாட்சிய அதினியம்',
      'பிரிவு [\\d\\(\\)\\s\\,\\-\\.\\u0B80-\\u0BFF]+(?:படி|கீழ்)',
      'இந்திய அரசியலமைப்பு சட்டம் 1950',
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
      'பாரதிய நியாய சன்ஹிதா, 2023 பிரிவு 198',
      'பாரதிய நியாய சன்ஹிதா, 2023 பிரிவு 199',
      'பாரதிய சாக்ஷ்ய அதிநியம், 2023 பிரிவு 109',
      'ரூ.10 இலட்சம்',
      'மனித உரிமை பாதுகாப்பு சட்டம் \\- 1993',
      'நுகர்வோர் பாதுகாப்பு சட்டம் \\- 1986',
      'பிரிவு 12',
      'நீதியைத்தேடி சட்ட விழிப்புணர்வு சங்கத்தில் உறுப்பினராகவும்', // Moved here for safety
      'நீதியைத் தேடி சட்ட விழிப்புணர்வு சங்கத்தில் உறுப்பினராகவும்', // With space
      'நீதியைத் தேடி சட்ட விழிப்புணர்வு சங்கத்தில்',
      'நீதியைத்தேடி சட்ட விழிப்புணர்வு சங்கத்தில்',
    ];

    String highlightedText = text;
    for (var pattern in yellowKeywords) {
      highlightedText = highlightedText.replaceAllMapped(
        RegExp(pattern, caseSensitive: false, multiLine: true), 
        (match) => '<b>${match.group(0)}</b>'
      );
    }

    // Keywords to underline (Red)
    // Keywords to underline (Red) - NOW EMPTY as they are moved to Yellow for consistency
    final redKeywords = [
       // 'நீதியைத்தேடி சட்ட விழிப்புணர்வு சங்கம்', // Moved to Yellow
    ];

    for (var pattern in redKeywords) {
      highlightedText = highlightedText.replaceAllMapped(
        RegExp(pattern, caseSensitive: false), 
        (match) => '<b>${match.group(0)}</b>'
      );
    }
    
    return highlightedText;
  }
}
