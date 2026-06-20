class Order {
  final String? id;
  final String? customerId;
  final String? artisanId;
  final String? farmerId;
  final String? sourceRequestId;
  final String? productId;
  final String? batchId;
  final String productName;
  final String? productType;
  final String orderType;
  final int quantity;
  final String quantityUnit;
  final String? fulfillmentType;
  final String fulfillmentStatus;
  final String status;
  final String? notes;
  final double price;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? rejectedAt;
  final DateTime? completedAt;
  final DateTime? handoverOtpExpiresAt;
  final DateTime? handoverVerifiedAt;
  final DateTime? receiverConfirmedAt;
  final Map<String, dynamic>? customer;
  final Map<String, dynamic>? artisan;
  final Map<String, dynamic>? farmer;
  final Map<String, dynamic>? product;
  final Map<String, dynamic>? batch;

  Order({
    this.id,
    this.customerId,
    this.artisanId,
    this.farmerId,
    this.sourceRequestId,
    this.productId,
    this.batchId,
    required this.productName,
    this.productType,
    required this.orderType,
    required this.quantity,
    required this.quantityUnit,
    this.fulfillmentType,
    this.fulfillmentStatus = 'pending_handover',
    required this.status,
    this.notes,
    required this.price,
    required this.createdAt,
    this.acceptedAt,
    this.rejectedAt,
    this.completedAt,
    this.handoverOtpExpiresAt,
    this.handoverVerifiedAt,
    this.receiverConfirmedAt,
    this.customer,
    this.artisan,
    this.farmer,
    this.product,
    this.batch,
  });

  factory Order.fromJson(Map<String, dynamic> data) {
    final rawQuantity = data['quantity'];
    final rawPrice = data['price'];
    return Order(
      id: data['id']?.toString(),
      customerId: data['customerId']?.toString(),
      artisanId: data['artisanId']?.toString(),
      farmerId: data['farmerId']?.toString(),
      sourceRequestId: data['sourceRequestId']?.toString(),
      productId: data['productId']?.toString(),
      batchId: data['batchId']?.toString(),
      productName: data['productName']?.toString() ?? '',
      productType: data['productType']?.toString(),
      orderType: data['orderType']?.toString() ?? 'product_order',
      quantity: rawQuantity is int
          ? rawQuantity
          : int.tryParse(rawQuantity?.toString() ?? '') ?? 1,
      quantityUnit: data['quantityUnit']?.toString() ?? 'item',
      fulfillmentType: data['fulfillmentType']?.toString(),
      fulfillmentStatus:
          data['fulfillmentStatus']?.toString() ?? 'pending_handover',
      status: data['status']?.toString() ?? '',
      notes: data['notes']?.toString(),
      price: rawPrice is num
          ? rawPrice.toDouble()
          : double.tryParse(rawPrice?.toString() ?? '') ?? 0,
      createdAt:
          DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      acceptedAt: DateTime.tryParse(data['acceptedAt']?.toString() ?? ''),
      rejectedAt: DateTime.tryParse(data['rejectedAt']?.toString() ?? ''),
      completedAt: DateTime.tryParse(data['completedAt']?.toString() ?? ''),
      handoverOtpExpiresAt: DateTime.tryParse(
        data['handoverOtpExpiresAt']?.toString() ?? '',
      ),
      handoverVerifiedAt: DateTime.tryParse(
        data['handoverVerifiedAt']?.toString() ?? '',
      ),
      receiverConfirmedAt: DateTime.tryParse(
        data['receiverConfirmedAt']?.toString() ?? '',
      ),
      customer: data['customer'] as Map<String, dynamic>?,
      artisan: data['artisan'] as Map<String, dynamic>?,
      farmer: data['farmer'] as Map<String, dynamic>?,
      product: data['product'] as Map<String, dynamic>?,
      batch: data['batch'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productName': productName,
      'productType': productType,
      'productId': productId,
      'batchId': batchId,
      'orderType': orderType,
      'quantity': quantity,
      'quantityUnit': quantityUnit,
      'fulfillmentType': fulfillmentType,
      'fulfillmentStatus': fulfillmentStatus,
      'status': status,
      'notes': notes,
      'price': price,
      'artisanId': artisanId,
    };
  }
}
