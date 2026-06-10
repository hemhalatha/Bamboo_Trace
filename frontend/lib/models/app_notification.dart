class AppNotification {
  final String id;
  final String type;
  final String title;
  final String body;
  final String entityType;
  final String entityId;
  final String navigationTarget;
  final DateTime? readAt;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.entityType,
    required this.entityId,
    required this.navigationTarget,
    this.readAt,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> data) {
    return AppNotification(
      id: data['id'] ?? '',
      type: data['type'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      entityType: data['entityType'] ?? '',
      entityId: data['entityId'] ?? '',
      navigationTarget: data['navigationTarget'] ?? '',
      readAt: DateTime.tryParse(data['readAt'] ?? ''),
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
