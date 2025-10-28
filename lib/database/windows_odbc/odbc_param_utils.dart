class OdbcParamEntry {
  OdbcParamEntry(this.name, this.value);

  final String name;
  final dynamic value;
}

class OdbcPreparedStatement {
  OdbcPreparedStatement({required this.sql, required this.entries});

  final String sql;
  final List<OdbcParamEntry> entries;
}

OdbcPreparedStatement prepareStatement(
  String sql,
  Map<String, dynamic> params,
) {
  final normalized = <String, dynamic>{};
  params.forEach((key, value) {
    final normalizedKey = key.startsWith('@') ? key.substring(1) : key;
    normalized[normalizedKey.toLowerCase()] = value;
  });

  final entries = <OdbcParamEntry>[];
  final buffer = StringBuffer();
  final length = sql.length;

  var index = 0;
  var inSingleQuote = false;

  bool isIdentifierStart(int code) =>
      (code >= 65 && code <= 90) || (code >= 97 && code <= 122) || code == 95;

  bool isIdentifierPart(int code) =>
      isIdentifierStart(code) || (code >= 48 && code <= 57);

  while (index < length) {
    final current = sql.codeUnitAt(index);
    final char = String.fromCharCode(current);

    if (char == "'") {
      buffer.write(char);
      index++;
      if (index < length && sql.codeUnitAt(index) == 39) {
        buffer.write("'");
        index++;
      } else {
        inSingleQuote = !inSingleQuote;
      }
      continue;
    }

    if (!inSingleQuote && char == '@') {
      if (index + 1 >= length) {
        buffer.write(char);
        index++;
        continue;
      }
      final nextCode = sql.codeUnitAt(index + 1);
      if (!isIdentifierStart(nextCode)) {
        buffer.write(char);
        index++;
        continue;
      }
      var end = index + 2;
      while (end < length && isIdentifierPart(sql.codeUnitAt(end))) {
        end++;
      }
      final name = sql.substring(index + 1, end);
      final lookupKey = name.toLowerCase();
      if (!normalized.containsKey(lookupKey)) {
        throw ArgumentError('Parameter @$name was not provided.');
      }
      buffer.write('?');
      entries.add(OdbcParamEntry('@$name', normalized[lookupKey]));
      index = end;
      continue;
    }

    buffer.write(char);
    index++;
  }

  if (entries.isEmpty && params.isNotEmpty) {
    throw ArgumentError(
      'No parameter placeholders found in SQL for provided parameters.',
    );
  }

  return OdbcPreparedStatement(sql: buffer.toString(), entries: entries);
}
