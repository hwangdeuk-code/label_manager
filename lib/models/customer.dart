// UTF-8, 한국어 주석
// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'package:flutter/material.dart';
import 'package:label_manager/core/app.dart';
import 'package:label_manager/database/db_client.dart';
import 'dao.dart';

class Customer {
  static Customer? instance;

  final int customerId;
  final String cooperatorId;
	final String customerName;

  const Customer({
    required this.customerId,
    required this.cooperatorId,
    required this.customerName,
  });

  static void setInstance(Customer? customer) {
    instance = customer;
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    String s(String key) => (map[key] ?? '').toString();
    int i(String key) => int.tryParse(s(key)) ?? 0;

    return Customer(
      customerId:   i('CUSTOMER_ID'),
      cooperatorId: s('COOP_ID'),
      customerName: s('NAME'),
    );
  }

  @override
  String toString() =>
    'CustomerId: $customerId, CoopId: $cooperatorId, CustomerName: $customerName';
}

class CustomerDAO extends DAO {
  static const String cn = 'CustomerDAO';

  static const String SelectSql = '''
		SELECT
      COALESCE(CONVERT(NVARCHAR(20), RICH_CUSTOMER_ID), N'') AS CUSTOMER_ID,
      COALESCE(CONVERT(NVARCHAR(30), RICH_COOP_ID COLLATE ${DAO.CP949}), N'') AS COOP_ID,
      COALESCE(CONVERT(NVARCHAR(50), RICH_NAME COLLATE ${DAO.CP949}), N'') AS NAME
		FROM BM_CUSTOMER
  ''';

  // WHERE 절: Customer ID로 조회 (Integer)
  static const String WhereSqlCustomerId = '''
	  WHERE RICH_CUSTOMER_ID=@customerId
  ''';

  static Future<Customer?> getByCustomerId(int customerId) async {
    const fn = 'getByCustomerId';
    debugPrint('$cn.$fn: $START, customerId:$customerId');

    try {
			final res = await DbClient.instance.getDataWithParams(
				'$SelectSql $WhereSqlCustomerId', { 'customerId': customerId }
			);

      final map = DAO.getRowMapFromResult(res);
  
      debugPrint('$cn.$fn: $END');
      return Customer.fromMap(map);
    }
    catch (e) {
      debugPrint('$cn.$fn: $END, $e');
      throw Exception('[$cn.$fn] $e');
    }
  }
}
