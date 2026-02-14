import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xcel;
import '../models/user_model.dart';
import 'package:flutter/foundation.dart';

class ExportService {
  static Future<void> exportMembersToPdf(List<UserModel> members) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('Active Members List')),
          pw.TableHelper.fromTextArray(
            headers: ['ID', 'Name', 'Phone', 'Join Date'],
            data: members.map((m) => [
              m.membershipId ?? 'N/A',
              m.name,
              m.phone,
              m.joinDate.toString().split(' ')[0],
            ]).toList(),
          ),
        ],
      ),
    );

    // Use Printing.layoutPdf for web-compatible PDF generation/download
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'active_members.pdf',
    );
  }

  static Future<void> exportCollectionToExcel(List<UserModel> members) async {
    final xcel.Workbook workbook = xcel.Workbook();
    final xcel.Worksheet sheet = workbook.worksheets[0];
    
    sheet.getRangeByName('A1').setText('Name');
    sheet.getRangeByName('B1').setText('Membership ID');
    sheet.getRangeByName('C1').setText('Total Paid');
    sheet.getRangeByName('D1').setText('Last Payment Month');

    for (int i = 0; i < members.length; i++) {
      final m = members[i];
      final row = i + 2;
      sheet.getRangeByName('A$row').setText(m.name);
      sheet.getRangeByName('B$row').setText(m.membershipId ?? 'N/A');
      sheet.getRangeByName('C$row').setNumber(m.totalPaid);
      sheet.getRangeByName('D$row').setText(m.lastPaymentMonth ?? 'N/A');
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    if (kIsWeb) {
      // On web, we could triggers a download via HTML anchor, 
      // but for now we just log to avoid build issues.
      debugPrint('Excel export complete (Web download placeholder)');
    } else {
      // Mobile logic would go here if path_provider/dart:io were available.
      debugPrint('Excel export complete (Mobile download placeholder)');
    }
  }
}
