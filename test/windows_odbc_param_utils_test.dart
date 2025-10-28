import 'package:flutter_test/flutter_test.dart';
import 'package:label_manager/database/windows_odbc/odbc_param_utils.dart';

void main() {
  group('prepareStatement', () {
    test('replaces named parameters with question marks in order', () {
      final prepared = prepareStatement(
        'SELECT * FROM T WHERE A = @id AND B = @name',
        {'id': 42, 'name': 'Kim'},
      );
      expect(prepared.sql, 'SELECT * FROM T WHERE A = ? AND B = ?');
      expect(prepared.entries.length, 2);
      expect(prepared.entries[0].name, '@id');
      expect(prepared.entries[0].value, 42);
      expect(prepared.entries[1].name, '@name');
      expect(prepared.entries[1].value, 'Kim');
    });

    test('allows parameters to repeat in the SQL text', () {
      final prepared = prepareStatement(
        'SELECT * FROM T WHERE A = @id OR B = @id',
        {'@id': 99},
      );
      expect(prepared.sql, 'SELECT * FROM T WHERE A = ? OR B = ?');
      expect(prepared.entries.length, 2);
      expect(prepared.entries[0].value, 99);
      expect(prepared.entries[1].value, 99);
    });

    test('does not replace placeholders inside string literals', () {
      final prepared = prepareStatement("SELECT '@id' AS literal, C = @id", {
        'id': 5,
      });
      expect(prepared.sql, "SELECT '@id' AS literal, C = ?");
      expect(prepared.entries.length, 1);
      expect(prepared.entries.single.value, 5);
    });

    test('throws when placeholder is missing in params', () {
      expect(() => prepareStatement('SELECT @id', {}), throwsArgumentError);
    });

    test('throws when params are given but no placeholders exist', () {
      expect(
        () => prepareStatement('SELECT 1', {'id': 1}),
        throwsArgumentError,
      );
    });
  });
}
