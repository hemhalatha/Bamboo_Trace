class OrderRequest {
  final String id;
  final String requestType;
  final String senderId;
  final String receiverId;
  final String? orderId;
  final String? productId;
  final String? batchId;
  final int quantity;
  final String quantityUnit;
  final String? notes;
  final String status;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final Map<String, dynamic>? sender;
  final Map<String, dynamic>? receiver;
  final Map<String, dynamic>? product;
  final Map<String, dynamic>? batch;
  final Map<String, dynamic>? order;

  OrderRequest({
    required this.id,
    required this.requestType,
    required this.senderId,
    required this.receiverId,
    this.orderId,
    this.productId,
    this.batchId,
    required this.quantity,
    required this.quantityUnit,
    this.notes,
    required this.status,
    required this.createdAt,
    this.respondedAt,
    this.sender,
    this.receiver,
    this.product,
    this.batch,
    this.order,
  });

  factory OrderRequest.fromJson(Map<String, dynamic> data) {
    return OrderRequest(
      id: data['id'] ?? '',
      requestType: data['requestType'] ?? '',
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      orderId: data['orderId'],
      productId: data['productId'],
      batchId: data['batchId'],
      quantity: data['quantity'] ?? 1,
      quantityUnit: data['quantityUnit'] ?? 'item',
      notes: data['notes'],
      status: data['status'] ?? '',
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
      respondedAt: DateTime.tryParse(data['respondedAt'] ?? ''),
      sender: data['sender'] as Map<String, dynamic>?,
      receiver: data['receiver'] as Map<String, dynamic>?,
      product: data['product'] as Map<String, dynamic>?,
      batch: data['batch'] as Map<String, dynamic>?,
      order: data['order'] as Map<String, dynamic>?,
    );
  }
}
