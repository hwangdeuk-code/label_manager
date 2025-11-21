// UTF-8, 한국어 주석
// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:label_manager/core/app.dart';
import 'package:label_manager/models/dao.dart';
import 'package:label_manager/database/db_client.dart';

class NoticeDAO extends DAO {
  static const String cn = 'NoticeDAO';
  static const String Sql = '''
    SELECT
      COALESCE(CONVERT(NVARCHAR(3000), UN_MSG COLLATE ${DAO.CP949}), N'') AS UN_MSG
    FROM
      BM_UPDATE_NOTICE
    WHERE
      LTRIM(RTRIM(CONVERT(NVARCHAR(30),UN_USER_ID COLLATE ${DAO.CP949}))) =
      LTRIM(RTRIM(CONVERT(NVARCHAR(30),@userId)));
  ''';
 
  static Future<String> getByUserId(String userId) async {
    const fn = 'getByUserId';
    debugPrint('$cn.$fn: $START, userId:$userId');

    try {
			final res = await DbClient.instance.getDataWithParams(
        Sql, { 'userId': userId }
			);

      final map = DAO.getRowMapFromResult(res);
      
      debugPrint('$cn.$fn: $END');
      return map.values.first as String;
    }
    catch (e) {
      debugPrint('$cn.$fn: $END, $e');
      throw Exception('[$cn.$fn] $e');
    }
  }
}
