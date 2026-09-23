import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/voucher.dart';

/// Construit un document PDF A4 contenant une grille de vouchers.
///
/// Layout anti-débordement : chaque ticket est confiné dans une cellule
/// à hauteur fixe calculée depuis la hauteur de la page.
Future<Uint8List> buildVoucherPdf({
  required List<Voucher> vouchers,
  String appTitle = 'Mikhmon Wifi',
  int perPage = 6,
}) async {
  final doc = pw.Document();
  if (vouchers.isEmpty) {
    return doc.save();
  }

  const pageWidth = PdfPageFormat.a4.width; // 595 pt
  const pageHeight = PdfPageFormat.a4.height; // 842 pt
  const margin = 18.0;
  const gap = 6.0;

  final cols = 2;
  final rowsPerPage = (perPage / cols).ceil();
  final usableW = pageWidth - margin * 2 - gap;
  final cellW = usableW / cols;
  final usableH =
      pageHeight - margin * 2 - gap * (rowsPerPage - 1) - 24; // entête
  final cellH = usableH / rowsPerPage;

  for (var start = 0; start < vouchers.length; start += perPage) {
    final slice = vouchers.sublist(
      start,
      (start + perPage).clamp(0, vouchers.length).toInt(),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(margin),
        header: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(appTitle,
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700)),
            pw.Text(
              'Feuille ${(start ~/ perPage) + 1} — ${vouchers.length} vouchers',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
            ),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.Text(
            'Généré par ${appTitle} — ${DateTime.now().toString().substring(0, 16)}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey400),
          ),
        ),
        build: (context) => [
          pw.Wrap(
            spacing: gap,
            runSpacing: gap,
            children: slice.map((v) => _ticket(v, cellW, cellH)).toList(),
          ),
        ],
      ),
    );
  }
  return doc.save();
}

pw.Widget _ticket(Voucher v, double w, double h) {
  return pw.Container(
    width: w,
    height: h,
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.blueGrey700, width: 1),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Flexible(
              child: pw.Text(
                v.profileName,
                maxLines: 1,
                overflow: pw.TextOverflow.ellipsis,
                style: pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey600),
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: pw.BoxDecoration(
                color: PdfColors.green700,
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Text(
                v.price == v.price.roundToDouble()
                    ? '${v.price.toStringAsFixed(0)} ${v.currencySymbol}'
                    : '${v.price.toStringAsFixed(2)} ${v.currencySymbol}',
                style: pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold),
              ),
            ),
          ],
        ),
        pw.Center(
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                v.username,
                maxLines: 1,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'Mot de passe : ${v.password}',
                maxLines: 1,
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
              ),
            ],
          ),
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Flexible(
              child: pw.Text(
                v.validityLabel,
                maxLines: 1,
                overflow: pw.TextOverflow.ellipsis,
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ),
            pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: v.code,
              width: 44,
              height: 44,
            ),
          ],
        ),
      ],
    ),
  );
}