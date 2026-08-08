/// PDF Font Helper — Loads Marathi / Devanagari Unicode compatible fonts for PDF generation
library;

import 'package:flutter/foundation.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfFontHelper {
  PdfFontHelper._();

  static pw.Font? _cachedRegular;
  static pw.Font? _cachedBold;
  static pw.ThemeData? _cachedTheme;

  /// Loads Google Font Noto Sans Devanagari for rendering Marathi and English text in PDFs.
  /// Falls back to standard Helvetica fonts if offline or font load fails.
  static Future<pw.ThemeData> getDevanagariTheme() async {
    if (_cachedTheme != null) return _cachedTheme!;

    try {
      final regular = _cachedRegular ?? await PdfGoogleFonts.notoSansDevanagariRegular();
      final bold = _cachedBold ?? await PdfGoogleFonts.notoSansDevanagariBold();
      _cachedRegular = regular;
      _cachedBold = bold;

      _cachedTheme = pw.ThemeData.withFont(
        base: regular,
        bold: bold,
        italic: regular,
        boldItalic: bold,
      );
      return _cachedTheme!;
    } catch (e) {
      debugPrint('[PdfFontHelper] Devanagari font load failed ($e), falling back to Helvetica');
      return pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      );
    }
  }

  /// Get regular and bold fonts tuple
  static Future<(pw.Font regular, pw.Font bold)> getFonts() async {
    try {
      final regular = _cachedRegular ?? await PdfGoogleFonts.notoSansDevanagariRegular();
      final bold = _cachedBold ?? await PdfGoogleFonts.notoSansDevanagariBold();
      _cachedRegular = regular;
      _cachedBold = bold;
      return (regular, bold);
    } catch (_) {
      return (pw.Font.helvetica(), pw.Font.helveticaBold());
    }
  }
}
