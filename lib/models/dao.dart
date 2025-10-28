// UTF-8, 한국어 주석
// ignore_for_file: constant_identifier_names, non_constant_identifier_names
import 'dart:convert';

class DAO {
  static const String CP949 = 'Korean_Wansung_CI_AS';
  static const String LINE_U16LE = 'LINE_U16LE';
  static const String SPLITTER = '^';
  static const String exception = 'Exception';
  static const String incorrect_format = 'Incorrect format';
  static const String no_rows_result = 'No rows in result';
  static const String unsupported_result_type = 'Unsupported result type';
  static const int query_timeouts = 5;

  static List<dynamic> getRowFromResult(Object jsonOrMap) {
		final Map<String, dynamic> m = switch (jsonOrMap) {
      final String s => jsonDecode(s) as Map<String, dynamic>,
      final Map mm when mm is Map<String, dynamic> => mm,
        _ => throw ArgumentError(unsupported_result_type),
    };

    final rows = (m['rows'] as List?) ?? const [];
    if (rows.isEmpty) throw StateError(no_rows_result);		
		final row = rows.first as Map<String, dynamic>;
    return row.values.toList(growable: false);
  }

  static Map<String, dynamic> getRowMapFromResult(Object jsonOrMap) {
    final Map<String, dynamic> m = switch (jsonOrMap) {
      final String s => jsonDecode(s) as Map<String, dynamic>,
      final Map mm when mm is Map<String, dynamic> => mm,
      _ => throw ArgumentError(unsupported_result_type),
    };

    final rows = (m['rows'] as List?) ?? const [];
    if (rows.isEmpty) throw StateError(no_rows_result);
    return rows.first as Map<String, dynamic>;
  }

  static List<dynamic> getRowsFromResult(Object jsonOrMap) {
		final Map<String, dynamic> m = switch (jsonOrMap) {
      final String s => jsonDecode(s) as Map<String, dynamic>,
      final Map mm when mm is Map<String, dynamic> => mm,
        _ => throw ArgumentError(unsupported_result_type),
    };

    final rows = (m['rows'] as List?) ?? const [];
    if (rows.isEmpty) throw StateError(no_rows_result);		
    return rows;
  }
}
