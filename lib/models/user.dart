// UTF-8, 한국어 주석
// ignore_for_file: constant_Identifier_names, non_constant_Identifier_names

import 'package:flutter/material.dart';
import 'package:label_manager/core/app.dart';
import 'package:label_manager/database/db_client.dart';
import 'dao.dart';

enum UserGrade {
	SYSTEM_ADMIN_USER(0),
	COOP_ADMIN_USER(1),
	MANAGER_USER(2),
	CLIENT_USER(3);

  final int code;
  const UserGrade(this.code);
  static UserGrade fromCode(int code) => UserGrade.values.firstWhere((e) => e.code == code);

  String get label {
    switch (this) {
      case UserGrade.SYSTEM_ADMIN_USER:
        return '시스템 관리자';
      case UserGrade.COOP_ADMIN_USER:
        return '협력업체 관리자';
      case UserGrade.MANAGER_USER:
        return '책임자';
      case UserGrade.CLIENT_USER:
        return '일반 사용자';
    }
  }  
}

class User {
  static const String SYSTEM = 'SYSTEM';
  static User? instance;
 
	final String userId;
	final int marketId;
	final String name;
	final String pwd;
	final UserGrade grade;
	final String marketName;
	final String customerName;

  const User({
    required this.userId,
    required this.marketId,
    required this.name,
    required this.pwd,
    required this.grade,
    required this.marketName,
    required this.customerName,
  });

  static void setInstance(User? user) {
    instance = user;
  }

	static User fromMap(Map<String, dynamic> map) {
    String s(String key) => (map[key] ?? '').toString();
    int i(String key) => int.tryParse(s(key)) ?? 0;

    return User(
      userId:       s('USER_ID'),
      marketId:     i('MARKET_ID'),
      name:         s('NAME'),
      pwd:          s('PASSWORD'),
      grade:        UserGrade.fromCode(i('GRADE')),
      marketName:   s('MARKET_NAME'),
      customerName: s('CUSTOMER_NAME'),
    );
  }

  @override
  String toString() =>
    '$userId ($name), MarketId: $marketId, Grade: $grade, Market: $marketName, Customer: $customerName';
}

class UserDAO extends DAO {
  static const String cn = 'UserDAO';

  static const String SelectSql = '''
    SELECT
      COALESCE(CONVERT(NVARCHAR(30), P1.RICH_USER_ID COLLATE ${DAO.CP949}), N'') AS USER_ID,
      COALESCE(CONVERT(NVARCHAR(20), P1.RICH_MARKET_ID), N'') as MARKET_ID,
      COALESCE(CONVERT(NVARCHAR(50), P1.RICH_NAME COLLATE ${DAO.CP949}), N'') AS NAME,
      COALESCE(CONVERT(NVARCHAR(20), P1.RICH_PWD COLLATE ${DAO.CP949}), N'') AS PASSWORD,
      COALESCE(CONVERT(NVARCHAR(20), P1.RICH_USER_GRADE), N'') AS GRADE,
      COALESCE(CONVERT(NVARCHAR(50), P2.RICH_NAME COLLATE ${DAO.CP949}), N'') AS MARKET_NAME,
      COALESCE(CONVERT(NVARCHAR(50), P3.RICH_NAME COLLATE ${DAO.CP949}), N'') AS CUSTOMER_NAME
		FROM
      BM_USER P1
      INNER JOIN BM_MARKET P2
      ON P1.RICH_MARKET_ID=P2.RICH_MARKET_ID
      INNER JOIN BM_CUSTOMER P3
      ON P2.RICH_CUSTOMER_ID=P3.RICH_CUSTOMER_ID
      INNER JOIN BM_COOPERATOR P4
      ON P3.RICH_COOP_ID=P4.RICH_COOP_ID
  ''';

  static const String WhereSqlUserId = '''
    WHERE LTRIM(RTRIM(CONVERT(NVARCHAR(30),P1.RICH_USER_ID COLLATE ${DAO.CP949}))) =
          LTRIM(RTRIM(CONVERT(NVARCHAR(30),@userId)))
  ''';

  static Future<User?> getByUserId(String userId) async {
    const fn = 'getByUserId';
    debugPrint('$cn.$fn: $START, userId:$userId');

    try {
			final res = await DbClient.instance.getDataWithParams(
				'$SelectSql $WhereSqlUserId', { 'userId': userId }
			);

      final map = DAO.getRowMapFromResult(res);

      debugPrint('$cn.$fn: $END');
      return User.fromMap(map);
    }
    catch (e) {
      debugPrint('$cn.$fn: $END, $e');
      throw Exception('[$cn.$fn] $e');
    }
  }
}
