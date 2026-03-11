import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PdfService {
  /// Opens the invoice PDF by launching the GET URL in the default browser/viewer.
  /// The backend endpoint is marked [AllowAnonymous], so no auth headers are needed.
  static Future<bool> downloadAndOpenInvoicePdf(String invoiceId) async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:5290/api';
    final url = Uri.parse('$baseUrl/invoices/$invoiceId/pdf');
    if (await canLaunchUrl(url)) {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Opens any generic PDF from an endpoint by launching the GET URL
  static Future<bool> fetchAndShowPdf({required String endpoint, required String title}) async {
    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:5290/api';
    final cleanEndpoint = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    final url = Uri.parse('$baseUrl/$cleanEndpoint');
    
    if (await canLaunchUrl(url)) {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
