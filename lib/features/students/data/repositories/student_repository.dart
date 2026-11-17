import 'package:csv/csv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:slkc_app/core/constants/app_constants.dart';
import 'package:slkc_app/features/students/domain/models/student_model.dart';

/// Result summary of a CSV bulk student import operation.
class CsvImportResult {
  final int totalRows;
  final int successCount;
  final List<String> errors;

  const CsvImportResult({
    required this.totalRows,
    required this.successCount,
    required this.errors,
  });
}

/// Repository for Student CRUD operations and CSV bulk import.
class StudentRepository {
  final SupabaseClient _supabase;

  StudentRepository(this._supabase);

  /// Fetches students, optionally filtered by [classId].
  Future<List<StudentModel>> getStudents({String? classId}) async {
    var query = _supabase.from(AppConstants.tableStudents).select('''
          id,
          name,
          roll_no,
          class_id,
          is_active,
          created_at,
          classes ( name )
        ''');

    if (classId != null && classId.isNotEmpty) {
      query = query.eq('class_id', classId);
    }

    final response = await query.order('roll_no', ascending: true);

    final list = (response as List)
        .map((row) => StudentModel.fromMap(row as Map<String, dynamic>))
        .toList();

    // Natural sort: parses numbers so roll 2 appears before roll 10
    list.sort((a, b) {
      final aNum = int.tryParse(a.rollNo);
      final bNum = int.tryParse(b.rollNo);
      if (aNum != null && bNum != null) {
        return aNum.compareTo(bNum);
      }
      return a.rollNo.compareTo(b.rollNo);
    });

    return list;
  }

  /// Creates a single student.
  Future<void> createStudent({
    required String name,
    required String rollNo,
    required String classId,
  }) async {
    await _supabase.from(AppConstants.tableStudents).insert({
      'name': name.trim(),
      'roll_no': rollNo.trim(),
      'class_id': classId,
      'is_active': true,
    });
  }

  /// Updates student details.
  Future<void> updateStudent({
    required String id,
    required String name,
    required String rollNo,
    required String classId,
    required bool isActive,
  }) async {
    await _supabase
        .from(AppConstants.tableStudents)
        .update({
          'name': name.trim(),
          'roll_no': rollNo.trim(),
          'class_id': classId,
          'is_active': isActive,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }

  /// Deletes a student.
  Future<void> deleteStudent(String id) async {
    await _supabase.from(AppConstants.tableStudents).delete().eq('id', id);
  }

  /// Parses CSV content and inserts students for the designated [classId].
  ///
  /// Expected CSV format:
  ///   name,roll_no
  ///   Aarav Kumar,1
  ///   Diya Singh,2
  Future<CsvImportResult> importStudentsFromCsv({
    required String classId,
    required String csvContent,
  }) async {
    final rows = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(csvContent);

    if (rows.isEmpty) {
      throw Exception('The selected CSV file is empty.');
    }

    // Determine column indices from header row (if present)
    int nameIndex = 0;
    int rollIndex = 1;
    int startIndex = 0;

    final firstRow = rows.first.map((c) => c.toString().trim().toLowerCase()).toList();
    if (firstRow.contains('name') || firstRow.contains('roll_no') || firstRow.contains('roll')) {
      startIndex = 1; // Header row exists
      nameIndex = firstRow.indexOf('name');
      rollIndex = firstRow.contains('roll_no')
          ? firstRow.indexOf('roll_no')
          : firstRow.indexOf('roll');

      if (nameIndex == -1 || rollIndex == -1) {
        throw Exception(
          'CSV must include "name" and "roll_no" header columns.',
        );
      }
    }

    int successCount = 0;
    final List<String> errors = [];
    final List<Map<String, dynamic>> recordsToInsert = [];

    for (int i = startIndex; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || (row.length == 1 && row[0].toString().trim().isEmpty)) {
        continue; // Skip blank lines
      }

      if (row.length <= nameIndex || row.length <= rollIndex) {
        errors.add('Row ${i + 1}: Insufficient columns (expected name and roll number).');
        continue;
      }

      final studentName = row[nameIndex].toString().trim();
      final rollNo = row[rollIndex].toString().trim();

      if (studentName.isEmpty) {
        errors.add('Row ${i + 1}: Student name cannot be empty.');
        continue;
      }
      if (rollNo.isEmpty) {
        errors.add('Row ${i + 1}: Roll number cannot be empty.');
        continue;
      }

      recordsToInsert.add({
        'name': studentName,
        'roll_no': rollNo,
        'class_id': classId,
        'is_active': true,
      });
    }

    // Insert records in batch into Supabase
    for (final record in recordsToInsert) {
      try {
        await _supabase.from(AppConstants.tableStudents).insert(record);
        successCount++;
      } catch (e) {
        errors.add('Roll ${record['roll_no']} (${record['name']}): $e');
      }
    }

    return CsvImportResult(
      totalRows: recordsToInsert.length,
      successCount: successCount,
      errors: errors,
    );
  }
}
