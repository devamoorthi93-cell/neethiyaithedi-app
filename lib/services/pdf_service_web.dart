import 'package:web/web.dart' as web;
import 'dart:js_interop';

Future<void> printPdfWeb(String htmlContent) async {
  // Create a new window for printing
  final printWindow = web.window.open('', '_blank');
  
  if (printWindow != null) {
    printWindow.document.write(htmlContent.toJS);
    printWindow.document.close();
    
    // Wait for fonts to load explicitly
    await printWindow.document.fonts.ready.toDart;
    // Add a small buffer for layout stability
    await Future.delayed(const Duration(milliseconds: 500));
    
    printWindow.print();
    // Optional: printWindow.close(); // Don't close immediately so user can see/print
  }
}
