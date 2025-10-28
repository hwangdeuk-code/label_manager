// UTF-8, 한국어 주석
// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:label_manager/core/app.dart';
import 'package:label_manager/database/db_client.dart';
import 'dao.dart';

class Brand {
  static List<Brand>? datas;

  final int brandId;
  final int customerId;
  final String brandName;

  const Brand({
    required this.brandId,
    required this.customerId,
    required this.brandName,
  });

  static void setDatas(List<Brand>? values) {
    datas = values;
  }

  factory Brand.fromMap(Map<String, dynamic> map) {
    String s(String key) => (map[key] ?? '').toString();
    int i(String key) => int.tryParse(s(key)) ?? 0;

    return Brand(
      brandId:    i('BRAND_ID'),
      customerId: i('CUSTOMER_ID'),
      brandName:  s('BRAND_NAME'),
    );
  }

  static List<Brand> fromPipeLines(List<dynamic> rows) {
    final List<Brand> brands = [];
    for (var row in rows) {
      brands.add(Brand.fromMap(row as Map<String, dynamic>));
    }
    return brands;
  }

  @override
  String toString() =>
    'BrandId: $brandId, CustomerId: $customerId, BrandName: $brandName';
}

class BrandDAO extends DAO {
  static const String cn = 'BrandDAO';

  static const String SelectSql =
      '''
    SELECT
      COALESCE(CONVERT(NVARCHAR(20), RICH_BRAND_ID), N'') AS BRAND_ID,
      COALESCE(CONVERT(NVARCHAR(20), RICH_CUSTOMER_ID), N'') AS CUSTOMER_ID,
      COALESCE(CONVERT(NVARCHAR(50), RICH_BRAND_NAME COLLATE ${DAO.CP949}), N'') AS BRAND_NAME
    FROM BM_RICH_BRAND
  ''';

  // WHERE 절: Customer ID로 조회 (Integer)
  static const String WhereSqlCustomerId = '''
	  WHERE RICH_CUSTOMER_ID=@customerId
  ''';

  static const String OrderSqlByBrandrder = '''
	  ORDER BY RICH_BRAND_ORDER ASC
  ''';

  static Future<List<Brand>?> getByCustomerIdByBrandOrder(
    int customerId,
  ) async {
    const String fn = 'getByCustomerIdByBrandOrder';
    debugPrint('$cn.$fn: $START, customerId:$customerId');

    try {
      final res = await DbClient.instance.getDataWithParams(
        '$SelectSql $WhereSqlCustomerId $OrderSqlByBrandrder',
        { 'customerId': customerId }
      );

      final rows = DAO.getRowsFromResult(res);
      final brands = Brand.fromPipeLines(rows);

      debugPrint('$cn.$fn: $END');
      return brands;
    }
    catch (e) {
      debugPrint('$cn.$fn: $END, $e');
      throw Exception('[$cn.$fn] $e');
    }
  }
}
