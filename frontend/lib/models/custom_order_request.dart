class CustomOrderRequest {
  final String id;
  final String customerId;
  final String targetType;
  final String? targetArtisanId;
  final String? acceptedByArtisanId;
  final String? orderId;
  final String title;
  final String description;
  final int quantity;
  final double? budget;
  final DateTime? deadline;
  final String? imageUrl;
  final String status;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final bool rejectedByCurrentUser;
  final Map<String, dynamic>? customer;
  final Map<String, dynamic>? targetArtisan;
  final Map<String, dynamic>? acceptedByArtisan;

  CustomOrderRequest({
    required this.id,
    required this.customerId,
    required this.targetType,
    this.targetArtisanId,
    this.acceptedByArtisanId,
    this.orderId,
    required this.title,
    required this.description,
    required this.quantity,
    this.budget,
    this.deadline,
    this.imageUrl,
    required this.status,
    required this.createdAt,
    this.respondedAt,
    this.rejectedByCurrentUser = false,
    this.customer,
    this.targetArtisan,
    this.acceptedByArtisan,
  });

  factory CustomOrderRequest.fromJson(Map<String, dynamic> data) {
    final rawBudget = data['budget'];
    return CustomOrderRequest(
      id: data['id']?.toString() ?? '',
      customerId: data['customerId']?.toString() ?? '',
      targetType: data['targetType']?.toString() ?? 'specific_artisan',
      targetArtisanId: data['targetArtisanId']?.toString(),
      acceptedByArtisanId: data['acceptedByArtisanId']?.toString(),
      orderId: data['orderId']?.toString(),
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      quantity: int.tryParse(data['quantity']?.toString() ?? '') ?? 1,
      budget: rawBudget is num
          ? rawBudget.toDouble()
          : double.tryParse(rawBudget?.toString() ?? ''),
      deadline: DateTime.tryParse(data['deadline']?.toString() ?? ''),
      imageUrl: data['imageUrl']?.toString(),
      status: data['status']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(data['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      respondedAt: DateTime.tryParse(data['respondedAt']?.toString() ?? ''),
      rejectedByCurrentUser: data['rejectedByCurrentUser'] == true,
      customer: data['customer'] as Map<String, dynamic>?,
      targetArtisan: data['targetArtisan'] as Map<String, dynamic>?,
      acceptedByArtisan: data['acceptedByArtisan'] as Map<String, dynamic>?,
    );
  }
}
