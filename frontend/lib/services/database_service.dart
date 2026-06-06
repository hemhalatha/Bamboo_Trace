import 'package:flutter/foundation.dart';
import 'api_service.dart';

class DatabaseService extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  Stream<List<Map<String, dynamic>>> get userOrders {
    return Stream.fromFuture(_apiService.getOrders().then((orders) {
      return orders.map((data) {
        return {
          'id': data['id'] ?? '',
          'product': data['productName'] ?? '',
          'status': data['status'] ?? 'Pending',
          'date': (data['createdAt'] ?? '').toString().split('T').first,
          'price': data['price'] != null ? '₹${data['price']}' : '₹0',
        };
      }).toList();
    }));
  }

  Future<void> addOrder({
    required String productName,
    required String status,
    required double price,
  }) async {
    await _apiService.addOrder({
      'productName': productName,
      'status': status,
      'price': price,
    });
  }
}
