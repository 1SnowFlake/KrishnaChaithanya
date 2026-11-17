import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../domain/models/report_models.dart';

/// Service responsible for generating styled, multi-page PDF attendance reports
/// and invoking cross-platform native print/save dialogs.
class PdfExportService {
  /// Generates the raw PDF bytes for an [AttendanceReportSummary].
  static Future<Uint8List> generatePdfBytes(AttendanceReportSummary summary) async {
    final pdf = pw.Document();

    final dateFormat = DateFormat('yyyy-MM-dd');
    final dateRangeStr =
        '${dateFormat.format(summary.startDate)} to ${dateFormat.format(summary.endDate)}';
    final targetClassStr = summary.className ?? 'All Classes';
    final sessionStr = (summary.session ?? 'All Sessions').toUpperCase();

    // Built-in standard fonts for fast, 100% offline-compatible rendering
    final font = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
        ),
        header: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 1.5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'SCHOOL ATTENDANCE REPORT',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Generated: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.blue200),
                  ),
                  child: pw.Text(
                    targetClassStr,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Confidential - School Administration System',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 12),

            // Metadata summary card
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Date Range: $dateRangeStr',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Session: $sessionStr',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Overall Attendance: ${summary.overallPercentage.toStringAsFixed(1)}%',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: summary.overallPercentage >= summary.threshold
                              ? PdfColors.green800
                              : PdfColors.red800,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Low Threshold: < ${summary.threshold.toStringAsFixed(0)}%',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 14),

            // KPI Grid
            pw.Row(
              children: [
                _buildKpiPdfBox('Total Students', '${summary.totalStudents}', PdfColors.blue800),
                pw.SizedBox(width: 8),
                _buildKpiPdfBox('Total Sessions', '${summary.totalSessions}', PdfColors.blueGrey800),
                pw.SizedBox(width: 8),
                _buildKpiPdfBox(
                  'Avg Attendance',
                  '${summary.overallPercentage.toStringAsFixed(1)}%',
                  summary.overallPercentage >= summary.threshold
                      ? PdfColors.green700
                      : PdfColors.red700,
                ),
                pw.SizedBox(width: 8),
                _buildKpiPdfBox(
                  'Below Threshold',
                  '${summary.lowAttendanceCount}',
                  summary.lowAttendanceCount > 0 ? PdfColors.red700 : PdfColors.green700,
                ),
              ],
            ),

            pw.SizedBox(height: 16),

            // Section Header
            pw.Text(
              'Student Attendance Breakdown',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey900,
              ),
            ),
            pw.SizedBox(height: 6),

            // Students Table
            pw.TableHelper.fromTextArray(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue900,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8.5),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              headers: [
                'Roll No',
                'Student Name',
                'Class',
                'Sessions',
                'Present',
                'Absent',
                'Rate (%)',
                'Status',
              ],
              data: summary.students.map((s) {
                final isLow = s.isLowAttendance(summary.threshold);
                return [
                  s.rollNo,
                  s.studentName,
                  s.className,
                  '${s.totalSessions}',
                  '${s.presentCount}',
                  '${s.absentCount}',
                  '${s.attendancePercentage.toStringAsFixed(1)}%',
                  isLow ? 'ALERT (<${summary.threshold.toStringAsFixed(0)}%)' : 'NORMAL',
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildKpiPdfBox(String title, String value, PdfColor valueColor) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(4),
          color: PdfColors.white,
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the native system print preview / save dialog.
  static Future<void> exportAndPrintPdf(AttendanceReportSummary summary) async {
    final pdfBytes = await generatePdfBytes(summary);
    final fileName =
        'attendance_report_${DateFormat('yyyyMMdd').format(summary.startDate)}_${DateFormat('yyyyMMdd').format(summary.endDate)}.pdf';

    await Printing.layoutPdf(
      name: fileName,
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }
}
