import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/bamboo_types.dart';
import '../../models/app_notification.dart';
import '../../models/custom_order_request.dart';
import '../../models/order.dart';
import '../../models/order_request.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/remote_image.dart';

class NotificationTargetPage extends StatefulWidget {
  const NotificationTargetPage({super.key, required this.notification});

  final AppNotification notification;

  @override
  State<NotificationTargetPage> createState() => _NotificationTargetPageState();
}

class _NotificationTargetPageState extends State<NotificationTargetPage> {
  final _apiService = ApiService();
  late Future<Widget> _targetFuture;

  @override
  void initState() {
    super.initState();
    _targetFuture = _loadTarget();
  }

  String get _entityType {
    final rawType = widget.notification.entityType.trim();
    if (rawType.isNotEmpty) {
      return _normalizeEntityType(rawType);
    }
    final target = widget.notification.navigationTarget;
    if (target.startsWith('/orders/')) return 'order';
    if (target.startsWith('/order-requests/')) return 'order_request';
    if (target.startsWith('/custom-requests/')) return 'custom_order_request';
    if (target.startsWith('/custom-order-requests/')) {
      return 'custom_order_request';
    }
    if (target.startsWith('/requests/')) return 'order_request';
    if (target.startsWith('/batches/')) return 'batch';
    return '';
  }

  String get _entityId {
    if (widget.notification.entityId.isNotEmpty) {
      return widget.notification.entityId;
    }
    final parts = widget.notification.navigationTarget.split('/');
    return parts.isNotEmpty ? parts.last : '';
  }

  Future<Widget> _loadTarget() async {
    final currentUser = context.read<AuthService>().currentUser;
    final entityType = _entityType;
    final entityId = _entityId;
    if (entityType.isEmpty || entityId.isEmpty) {
      return _FallbackTarget(notification: widget.notification);
    }

    if (entityType == 'order') {
      final order = await _apiService.getOrderById(entityId);
      return _OrderDetail(
        order: order,
        currentUserId: currentUser?.id,
        currentRole: currentUser?.role,
      );
    }

    if (entityType == 'custom_order_request') {
      final request = await _apiService.getCustomOrderRequestById(entityId);
      return _CustomRequestDetail(request: request);
    }

    if (entityType == 'order_request') {
      final request = await _apiService.getOrderRequestById(entityId);
      return _OrderRequestDetail(request: request);
    }

    if (entityType == 'batch') {
      final batch = await _apiService.getBatchById(entityId);
      return _BatchDetail(batch: batch);
    }

    return _FallbackTarget(notification: widget.notification);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Notification Target')),
      body: FutureBuilder<Widget>(
        future: _targetFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _FallbackTarget(notification: widget.notification);
          }
          return snapshot.data ??
              _FallbackTarget(notification: widget.notification);
        },
      ),
    );
  }
}

class _OrderDetail extends StatelessWidget {
  const _OrderDetail({
    required this.order,
    required this.currentUserId,
    required this.currentRole,
  });

  final Order order;
  final String? currentUserId;
  final String? currentRole;

  @override
  Widget build(BuildContext context) {
    final isMaterialOrder = order.orderType == 'material_order';
    final buyerName = isMaterialOrder
        ? _nameFromUser(order.artisan)
        : _nameFromUser(order.customer);
    final sellerName = isMaterialOrder
        ? _nameFromUser(order.farmer)
        : _nameFromUser(order.artisan);
    final contact = _otherPartyContact(order, currentUserId, currentRole);
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _DetailHeader(title: order.productName, status: order.status),
        _DetailRow(label: 'Order type', value: order.orderType),
        _DetailRow(label: 'Buyer', value: buyerName),
        _DetailRow(label: 'Seller', value: sellerName),
        _DetailRow(
          label: 'Quantity',
          value: '${order.quantity} ${order.quantityUnit}',
        ),
        _DetailRow(
          label: 'Fulfillment type',
          value: order.fulfillmentType ?? 'Not specified',
        ),
        _DetailRow(
          label: 'Fulfillment status',
          value: order.fulfillmentStatus.replaceAll('_', ' '),
        ),
        _DetailRow(label: 'Order date', value: _formatDate(order.createdAt)),
        if (order.notes != null && order.notes!.isNotEmpty)
          _DetailRow(label: 'Notes', value: order.notes!),
        _ContactBlock(
          label: contact.label,
          user: contact.user,
          fallbackName: contact.fallbackName,
        ),
      ],
    );
  }
}

class _CustomRequestDetail extends StatelessWidget {
  const _CustomRequestDetail({required this.request});

  final CustomOrderRequest request;

  @override
  Widget build(BuildContext context) {
    final target = request.targetType == 'broadcast'
        ? 'Broadcast to all artisans'
        : request.targetArtisan?['name']?.toString() ?? 'Specific artisan';
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _DetailHeader(title: request.title, status: request.status),
        _DetailRow(
          label: 'Customer',
          value: request.customer?['name']?.toString() ?? 'Customer',
        ),
        _DetailRow(label: 'Target', value: target),
        _DetailRow(label: 'Quantity', value: request.quantity.toString()),
        if (request.budget != null)
          _DetailRow(label: 'Budget', value: request.budget.toString()),
        if (request.deadline != null)
          _DetailRow(label: 'Deadline', value: _formatDate(request.deadline!)),
        if (request.imageUrl != null && request.imageUrl!.isNotEmpty)
          RemoteImage(
            imageUrl: request.imageUrl,
            height: 180,
            width: double.infinity,
            icon: Icons.design_services,
          ),
        _DetailRow(label: 'Description', value: request.description),
      ],
    );
  }
}

class _OrderRequestDetail extends StatelessWidget {
  const _OrderRequestDetail({required this.request});

  final OrderRequest request;

  @override
  Widget build(BuildContext context) {
    final item =
        request.product?['productName'] ??
        request.batch?['batchId'] ??
        'Request';
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _DetailHeader(title: item.toString(), status: request.status),
        _DetailRow(label: 'Request type', value: request.requestType),
        _DetailRow(
          label: 'Sender',
          value: request.sender?['name']?.toString() ?? 'Sender',
        ),
        _DetailRow(
          label: 'Receiver',
          value: request.receiver?['name']?.toString() ?? 'Receiver',
        ),
        _DetailRow(
          label: 'Quantity',
          value: '${request.quantity} ${request.quantityUnit}',
        ),
        _DetailRow(label: 'Created', value: _formatDate(request.createdAt)),
        if (request.notes != null && request.notes!.isNotEmpty)
          _DetailRow(label: 'Notes', value: request.notes!),
      ],
    );
  }
}

class _BatchDetail extends StatelessWidget {
  const _BatchDetail({required this.batch});

  final Map<String, dynamic> batch;

  @override
  Widget build(BuildContext context) {
    final status = batch['status']?.toString() ?? 'available';
    final quantity = batch['quantityAvailable'] ?? batch['quantity'] ?? 0;
    final unit = batch['quantityUnit'] ?? 'kg';
    final farmerName = batch['farmerName']?.toString();
    final farmerLocation =
        batch['farmerLocation']?.toString() ?? batch['location']?.toString();
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _DetailHeader(
          title: displayBambooType(batch['type']),
          status: status,
        ),
        _DetailRow(
          label: 'Batch ID',
          value: batch['batchId']?.toString() ?? 'Not available',
        ),
        _DetailRow(label: 'Quantity', value: '$quantity $unit'),
        if (farmerName != null && farmerName.isNotEmpty)
          _DetailRow(label: 'Farmer', value: farmerName),
        if (farmerLocation != null && farmerLocation.isNotEmpty)
          _DetailRow(label: 'Location', value: farmerLocation),
        if (batch['availableFromDate'] != null)
          _DetailRow(
            label: 'Available from',
            value: batch['availableFromDate'].toString(),
          ),
        if (batch['expectedHarvestDate'] != null)
          _DetailRow(
            label: 'Expected harvest',
            value: batch['expectedHarvestDate'].toString(),
          ),
      ],
    );
  }
}

class _FallbackTarget extends StatelessWidget {
  const _FallbackTarget({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _DetailHeader(title: notification.title, status: 'Unavailable'),
        Text(notification.body),
        SizedBox(height: 16),
        _DetailRow(label: 'Entity type', value: notification.entityType),
        _DetailRow(label: 'Entity ID', value: notification.entityId),
        _DetailRow(
          label: 'Navigation target',
          value: notification.navigationTarget,
        ),
        SizedBox(height: 16),
        Text('The target page could not be opened safely.'),
      ],
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.title, required this.status});

  final String title;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Chip(label: Text(status.replaceAll('_', ' '))),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 2),
          Text(value.isEmpty ? 'Not available' : value),
        ],
      ),
    );
  }
}

class _ContactBlock extends StatelessWidget {
  const _ContactBlock({
    required this.label,
    required this.user,
    required this.fallbackName,
  });

  final String label;
  final Map<String, dynamic>? user;
  final String fallbackName;

  @override
  Widget build(BuildContext context) {
    final phone = user?['phone']?.toString();
    final email = user?['email']?.toString();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(height: 2),
          Text(_nameFromUser(user, fallback: fallbackName)),
          if (phone != null && phone.isNotEmpty) Text('Phone: $phone'),
          if (email != null && email.isNotEmpty) Text('Email: $email'),
          Text('Address: ${_addressFromUser(user)}'),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _normalizeEntityType(String entityType) {
  final normalized = entityType.trim().toLowerCase().replaceAll('-', '_');
  if (normalized == 'orders') return 'order';
  if (normalized == 'order_requests') return 'order_request';
  if (normalized == 'requests') return 'order_request';
  if (normalized == 'custom_request') return 'custom_order_request';
  if (normalized == 'custom_order_requests') return 'custom_order_request';
  if (normalized == 'custom_requests') return 'custom_order_request';
  if (normalized == 'batches') return 'batch';
  return normalized;
}

({String label, Map<String, dynamic>? user, String fallbackName})
_otherPartyContact(Order order, String? currentUserId, String? currentRole) {
  if (order.orderType == 'material_order') {
    if (order.artisanId == currentUserId || currentRole == 'artisan') {
      return (
        label: 'Farmer',
        user: order.farmer,
        fallbackName: 'Farmer seller',
      );
    }
    return (
      label: 'Artisan',
      user: order.artisan,
      fallbackName: 'Artisan buyer',
    );
  }

  if (order.artisanId == currentUserId || currentRole == 'artisan') {
    return (
      label: 'Customer',
      user: order.customer,
      fallbackName: 'Customer buyer',
    );
  }

  return (
    label: 'Artisan',
    user: order.artisan,
    fallbackName: 'Artisan seller',
  );
}

String _nameFromUser(
  Map<String, dynamic>? user, {
  String fallback = 'Not available',
}) {
  final name = user?['name']?.toString() ?? '';
  return name.isEmpty ? fallback : name;
}

String _addressFromUser(Map<String, dynamic>? user) {
  final parts = [
    user?['addressLine'],
    user?['city'],
    user?['district'],
    user?['state'],
    user?['pincode'],
    user?['landmark'],
  ]
      .map((part) => part?.toString().trim() ?? '')
      .where((part) => part.isNotEmpty)
      .toList();
  return parts.isEmpty ? 'Not specified' : parts.join(', ');
}
