// UTF-8, 한국어 주석
// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:label_manager/core/app.dart';
import 'package:label_manager/database/db_client.dart';
import 'dao.dart';

enum CooperatorGrade {
	COOP_GRADE_SYS_ADMIN(0),
	COOP_GRADE_COOP_MANAGER(1);

  final int code;
  const CooperatorGrade(this.code);
  static CooperatorGrade fromCode(int code) => CooperatorGrade.values.firstWhere((e) => e.code == code);

  String get label {
    switch (this) {
      case CooperatorGrade.COOP_GRADE_SYS_ADMIN:
        return '시스템 관리자';
      case CooperatorGrade.COOP_GRADE_COOP_MANAGER:
        return '협력업체 책임자';
    }
  }
}

class Cooperator {
  static Cooperator? instance;

	final String id;
	final String name;

  const Cooperator({
    required this.id,
    required this.name,
  });

  static void setInstance(Cooperator? cooperator) {
    instance = cooperator;
  }

  factory Cooperator.fromMap(Map<String, dynamic> map) {
    String s(String key) => (map[key] ?? '').toString();

    return Cooperator(
      id:   s('COOP_ID'),
      name: s('NAME'),
    );
  }

  @override
  String toString() => 'CooperatorId: $id, Name: $name';
}

class CooperatorDAO extends DAO {
  static const String cn = 'CooperatorDAO';

  static const String SelectSql = '''
    SELECT
      COALESCE(CONVERT(NVARCHAR(30), RICH_COOP_ID COLLATE ${DAO.CP949}), N'') AS COOP_ID,
      COALESCE(CONVERT(NVARCHAR(50), RICH_NAME COLLATE ${DAO.CP949}), N'') AS NAME
    FROM BM_COOPERATOR
  ''';

  static const String WhereSqlCooperatorId = '''
    WHERE LTRIM(RTRIM(CONVERT(NVARCHAR(30),RICH_COOP_ID COLLATE ${DAO.CP949}))) =
          LTRIM(RTRIM(CONVERT(NVARCHAR(30),@cooperatorId)))
  ''';

  static Future<Cooperator?> getByCooperatorId(String cooperatorId) async {
    const String fn = 'getByCooperatorId';
    debugPrint('$cn.$fn: $START, cooperatorId:$cooperatorId');

    try {
			final res = await DbClient.instance.getDataWithParams(
				'$SelectSql $WhereSqlCooperatorId', { 'cooperatorId': cooperatorId }
			);

      final map = DAO.getRowMapFromResult(res);

      debugPrint('$cn.$fn: $END');
      return Cooperator.fromMap(map);
    }
    catch (e) {
      debugPrint('$cn.$fn: $END, $e');
      throw Exception('[$cn.$fn] $e');
    }
  }
}
