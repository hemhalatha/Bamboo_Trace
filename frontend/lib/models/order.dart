class Order {
  final String? id;
  final String productName;
  final String status;
  final double price;
  final String artisanId;
  final DateTime createdAt;

  Order({
    this.id,
    required this.productName,
    required this.status,
    required this.price,
    required this.artisanId,
    required this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> data) {
    return Order(
      id: data['id'],
      productName: data['productName'] ?? '',
      status: data['status'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      artisanId: data['artisanId'] ?? '',
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productName': productName,
      'status': status,
      'price': price,
      'artisanId': artisanId,
    };
  }
}
