// UTF-8, 한국어 주석
// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:label_manager/core/app.dart';
import 'package:label_manager/database/db_client.dart';
import 'package:label_manager/database/db_result_utils.dart';
import 'package:r_get_ip/r_get_ip.dart';
import 'dao.dart';
import 'user.dart';

enum LoginCondition {
	LOGIN(0),
	LOGOUT(1);

  final int code;
  const LoginCondition(this.code);
  static LoginCondition fromCode(int code) => LoginCondition.values.firstWhere((e) => e.code == code);
}

class LoginLog {
 	final int logId;
	final String userId;
	final UserGrade userGrade;
	final String programVersion;
	final int customerId;
	final String customerName;
	final String loginDate;
	final String loginDateYYYYMMDD;
	final String lLoginIP;
	final LoginCondition loginCondition;

  const LoginLog({
    required this.logId,
    required this.userId,
    required this.userGrade,
    required this.programVersion,
    required this.customerId,
    required this.customerName,
    required this.loginDate,
    required this.loginDateYYYYMMDD,
    required this.lLoginIP,
    required this.loginCondition,
  });

  factory LoginLog.fromMap(Map<String, dynamic> map) {
    String s(String key) => (map[key] ?? '').toString();
    int i(String key) => int.tryParse(s(key)) ?? 0;

    return LoginLog(
      logId:              i('LOG_ID'),
      userId:             s('USER_ID'),
      userGrade:          UserGrade.fromCode(i('USER_GRADE')),
      programVersion:     s('PROGRAM_VERSION'),
      customerId:         i('CUSTOMER_ID'),
      customerName:       s('CUSTOMER_NAME'),
      loginDate:          s('LOGIN_DATE'),
      loginDateYYYYMMDD:  s('LOGIN_DATE_YYYYMMDD'),
      lLoginIP:           s('LOGIN_IP'),
      loginCondition:     LoginCondition.fromCode(i('LOGIN_CONDITION')),
    );
  }
}

class LoginLogDAO extends DAO {
  static const String cn = 'LoginLogDAO';

  static const String SelectSql = '''
  ''';

  static const String WhereSqlLogId = '''
  ''';

  static const String InsertSql = '''
    INSERT INTO BM_LOGIN_LOG
      (USER_ID,USER_GRADE,PROGRAM_VERSION,CUST_ID,CUST_NAME,
       LOGIN_DATE,LOGIN_DATE_YYYYMMDD,LOGIN_IP,LOGIN_CONDITION,LOGIN_OUTER_IP)
		VALUES
		  (CONVERT(NVARCHAR(30), CONVERT(VARCHAR(30), CONVERT(VARBINARY(100), @userId, 1)) COLLATE ${DAO.CP949}),
       CONVERT(NVARCHAR(20), CONVERT(VARCHAR(20), CONVERT(VARBINARY(100), @userGrade, 1)) COLLATE ${DAO.CP949}),
       CONVERT(NVARCHAR(50), CONVERT(VARCHAR(50), CONVERT(VARBINARY(150), @programVersion, 1)) COLLATE ${DAO.CP949}),
       @customerId,
       CONVERT(NVARCHAR(50), CONVERT(VARCHAR(50), CONVERT(VARBINARY(150), @customerName, 1)) COLLATE ${DAO.CP949}),
       @loginDate,
       CONVERT(NVARCHAR(8), CONVERT(VARCHAR(8), CONVERT(VARBINARY(30), @loginDateYYYYMMDD, 1)) COLLATE ${DAO.CP949}),
       CONVERT(NVARCHAR(32), CONVERT(VARCHAR(32), CONVERT(VARBINARY(100), @loginIP, 1)) COLLATE ${DAO.CP949}),
       @loginCondition,
       CONVERT(VARCHAR(15), CONNECTIONPROPERTY('client_net_address')))
  ''';

  static Future<LoginLog?> getByLogId(int logId) async {
    const fn = 'getByLogId';

    try {
			final res = await DbClient.instance.getDataWithParams(
				'$SelectSql $WhereSqlLogId', { 'logId': logId }
			);

      final map = DAO.getRowMapFromResult(res);

      return LoginLog.fromMap(map);
    }
    catch (e) {
      throw Exception('[$cn.$fn] $e');
    }
  }

  static Future<void> insertLoginLog({
    required String userId,
    required UserGrade userGrade,
    required int customerId,
    required String customerName,
    required LoginCondition loginCondition,
  }) async {
    const fn = 'InsertLoginLog';
    debugPrint('$cn.$fn: $START');

    try {
      final now = DateTime.now();
      final localIp = await RGetIp.internalIP;
      final hexUserId = await stringToHexCp949(userId);
      final hexUserGrade = await stringToHexCp949(userGrade.label);
      final hexProgramVersion = await stringToHexCp949(appVersion);
      final hexCustomerName = await stringToHexCp949(customerName); 
      final loginDate = DateFormat('yyyy-MM-dd HH:mm:ss', appLocale).format(now);
      final hexLoginDateYYYYMMDD = await stringToHexCp949(DateFormat('yyyyMMdd', appLocale).format(now));
      final hexLoginIP = await stringToHexCp949(localIp!);

      await DbClient.instance.writeDataWithParams(
        InsertSql,
        {
          'userId': hexUserId,
          'userGrade': hexUserGrade,
          'programVersion': hexProgramVersion,
          'customerId': customerId,
          'customerName': hexCustomerName,
          'loginDate': loginDate,
          'loginDateYYYYMMDD': hexLoginDateYYYYMMDD,
          'loginIP': hexLoginIP,
          'loginCondition': loginCondition.code,
        },

      );

      debugPrint('$cn.$fn: $END');
    }
    catch (e) {
      debugPrint('$cn.$fn: $e');
      throw Exception('[$cn.$fn] $e');
    }
  }
}
