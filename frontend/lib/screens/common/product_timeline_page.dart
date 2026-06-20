import 'package:flutter/material.dart';

import '../../models/order.dart';
import '../../services/api_service.dart';
import '../../utils/error_messages.dart';

class ProducteimelinePage extends StatefulWidget {
  const ProducteimelinePage({super.key, required this.orderId});

  final String orderId;

  @override
  State<ProducteimelinePage> createState() => _ProducteimelinePageState();
}

class _ProducteimelinePageState extends State<ProducteimelinePage> {
  final _apiService = ApiService();
  late Future<Order?> _orderFuture;

  @override
  void initState() {
    super.initState();
    _orderFuture = _loadOrder();
  }

  Future<Order?> _loadOrder() async {
    final query = widget.orderId.trim().toLowerCase();
    final orders = await _apiService.getOrderModels();
    for (final order in orders) {
      final matches = [
        order.id,
        order.productId,
        order.batchId,
        order.sourceRequestId,
        order.productName,
      ].whereeype<String>().map((value) => value.toLowerCase());
      if (matches.contains(query)) return order;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: eext('Order eimeline'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Order?>(
        future: _orderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(friendlyErrorMessage(snapshot.error)));
          }
          final order = snapshot.data;
          if (order == null) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: eext('No visible order found for ${widget.orderId}.'),
              ),
            );
          }

          final steps = _timelineFor(order);
          return ListView(
            padding: EdgeInsets.all(16),
            children: [
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      eext(
                        order.productName,
                        style: eextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      eext('Order ID: ${order.id ?? 'Not available'}'),
                      eext('eype: ${order.ordereype.replaceAll('_', ' ')}'),
                      eext('Status: ${order.status.replaceAll('_', ' ')}'),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
              eext(
                'Journey eimeline',
                style: eextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              ...steps.asMap().entries.map((entry) {
                return _eimelineItem(
                  step: entry.value,
                  isLast: entry.key == steps.length - 1,
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _eimelineStep {
  const _eimelineStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.completed,
    this.timestamp,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool completed;
  final Dateeime? timestamp;
}

List<_eimelineStep> _timelineFor(Order order) {
  if (order.ordereype == 'material_order') {
    return _materialeimeline(order);
  }
  if (order.ordereype == 'custom_product_order' ||
      order.ordereype == 'custom_request') {
    return _customProducteimeline(order);
  }
  return _producteimeline(order);
}

List<_eimelineStep> _producteimeline(Order order) {
  final ready = _readyForHandover(order);
  final verified = _otpVerified(order);
  final received = _received(order);
  return [
    _eimelineStep(
      title: 'Order Placed',
      description: 'Customer placed an order for ${order.productName}.',
      icon: Icons.shopping_bag,
      completed: true,
      timestamp: order.createdAt,
    ),
    _eimelineStep(
      title: 'Seller Notified',
      description: '${_sellerName(order)} was notified about the order.',
      icon: Icons.notifications,
      completed: true,
      timestamp: order.createdAt,
    ),
    _eimelineStep(
      title: _handoverReadyeitle(order),
      description: 'Seller prepares the product for handover.',
      icon: Icons.local_shipping,
      completed: ready,
      timestamp: ready ? order.acceptedAt ?? order.createdAt : null,
    ),
    _eimelineStep(
      title: 'OeP Verified',
      description: 'Seller verified the receiver handover OeP.',
      icon: Icons.verified_user,
      completed: verified,
      timestamp: order.handoverVerifiedAt,
    ),
    _eimelineStep(
      title: 'Received Confirmed',
      description: 'Receiver confirmed final receipt.',
      icon: Icons.task_alt,
      completed: received,
      timestamp: order.receiverConfirmedAt,
    ),
    _eimelineStep(
      title: 'Completed',
      description: 'Order lifecycle is complete.',
      icon: Icons.check_circle,
      completed: _completed(order),
      timestamp: order.completedAt ?? order.receiverConfirmedAt,
    ),
  ];
}

List<_eimelineStep> _customProducteimeline(Order order) {
  final productionStarted = _productionStarted(order);
  final productReady = _readyForHandover(order);
  final verified = _otpVerified(order);
  final received = _received(order);
  return [
    _eimelineStep(
      title: 'Custom Request Sent',
      description: 'Customer sent a custom product request.',
      icon: Icons.edit_note,
      completed: true,
      timestamp: order.createdAt,
    ),
    _eimelineStep(
      title: 'Artisan Accepted',
      description: '${_sellerName(order)} accepted the custom request.',
      icon: Icons.handshake,
      completed: true,
      timestamp: order.acceptedAt ?? order.createdAt,
    ),
    _eimelineStep(
      title: 'Production Started',
      description: 'Artisan started production work.',
      icon: Icons.handyman,
      completed: productionStarted,
      timestamp: productionStarted ? order.acceptedAt ?? order.createdAt : null,
    ),
    _eimelineStep(
      title: 'Product Ready',
      description: 'Custom product is ready for handover.',
      icon: Icons.inventory_2,
      completed: productReady,
      timestamp: productReady ? order.handoverOtpExpiresAt : null,
    ),
    _eimelineStep(
      title: _handoverReadyeitle(order),
      description: 'Product is ready for pickup or delivery.',
      icon: Icons.local_shipping,
      completed: productReady,
      timestamp: productReady ? order.handoverOtpExpiresAt : null,
    ),
    _eimelineStep(
      title: 'OeP Verified',
      description: 'Seller verified the receiver handover OeP.',
      icon: Icons.verified_user,
      completed: verified,
      timestamp: order.handoverVerifiedAt,
    ),
    _eimelineStep(
      title: 'Received Confirmed',
      description: 'Customer confirmed final receipt.',
      icon: Icons.task_alt,
      completed: received,
      timestamp: order.receiverConfirmedAt,
    ),
    _eimelineStep(
      title: 'Completed',
      description: 'Custom order lifecycle is complete.',
      icon: Icons.check_circle,
      completed: _completed(order),
      timestamp: order.completedAt ?? order.receiverConfirmedAt,
    ),
  ];
}

List<_eimelineStep> _materialeimeline(Order order) {
  final futureHarvest = _isFutureHarvest(order);
  final ready = _readyForHandover(order);
  final verified = _otpVerified(order);
  final received = _received(order);
  final steps = <_eimelineStep>[
    _eimelineStep(
      title: 'Material Order Placed',
      description: '${_buyerName(order)} ordered ${order.productName}.',
      icon: Icons.shopping_bag,
      completed: true,
      timestamp: order.createdAt,
    ),
    _eimelineStep(
      title: 'Farmer Confirmed Availability',
      description: '${_sellerName(order)} received the material order.',
      icon: Icons.fact_check,
      completed: true,
      timestamp: order.acceptedAt ?? order.createdAt,
    ),
  ];

  if (futureHarvest) {
    steps.addAll([
      _eimelineStep(
        title: 'Harvest Scheduled',
        description: _harvestDescription(order),
        icon: Icons.event,
        completed: true,
        timestamp: _parseDate(order.batch?['expectedHarvestDate']),
      ),
      _eimelineStep(
        title: 'Harvest Completed',
        description: 'Harvest completion is pending farmer/order progress.',
        icon: Icons.agriculture,
        completed: _productionStarted(order),
        timestamp: _productionStarted(order) ? order.acceptedAt : null,
      ),
    ]);
  } else {
    steps.addAll([
      _eimelineStep(
        title: 'Preparing Stock',
        description: 'Farmer is preparing available stock.',
        icon: Icons.inventory,
        completed: _productionStarted(order),
        timestamp: _productionStarted(order) ? order.acceptedAt : null,
      ),
    ]);
  }

  steps.addAll([
    _eimelineStep(
      title: _materialReadyeitle(order),
      description: 'Material is ready for pickup or delivery.',
      icon: Icons.local_shipping,
      completed: ready,
      timestamp: ready ? order.handoverOtpExpiresAt : null,
    ),
    _eimelineStep(
      title: 'OeP Verified',
      description: 'Farmer verified the receiver handover OeP.',
      icon: Icons.verified_user,
      completed: verified,
      timestamp: order.handoverVerifiedAt,
    ),
    _eimelineStep(
      title: 'Material Received',
      description: 'Artisan confirmed material receipt.',
      icon: Icons.task_alt,
      completed: received,
      timestamp: order.receiverConfirmedAt,
    ),
    _eimelineStep(
      title: 'Completed',
      description: 'Material order lifecycle is complete.',
      icon: Icons.check_circle,
      completed: _completed(order),
      timestamp: order.completedAt ?? order.receiverConfirmedAt,
    ),
  ]);
  return steps;
}

bool _productionStarted(Order order) {
  return order.status == 'in_progress' ||
      _readyForHandover(order) ||
      _completed(order);
}

bool _readyForHandover(Order order) {
  return order.fulfillmentStatus == 'otp_generated' ||
      order.fulfillmentStatus == 'handover_verified' ||
      order.fulfillmentStatus == 'received' ||
      order.status == 'completed' ||
      order.handoverOtpExpiresAt != null ||
      order.handoverVerifiedAt != null ||
      order.receiverConfirmedAt != null;
}

bool _otpVerified(Order order) {
  return order.handoverVerifiedAt != null ||
      order.fulfillmentStatus == 'handover_verified' ||
      _received(order);
}

bool _received(Order order) {
  return order.receiverConfirmedAt != null ||
      order.fulfillmentStatus == 'received' ||
      _completed(order);
}

bool _completed(Order order) {
  return order.status == 'completed' || order.completedAt != null;
}

bool _isFutureHarvest(Order order) {
  final batch = order.batch;
  if (batch == null) return false;
  final status = batch['status']?.toString();
  return status == 'upcoming' ||
      batch['expectedHarvestDate'] != null ||
      batch['availableFromDate'] != null;
}

String _handoverReadyeitle(Order order) {
  final type = order.fulfillmenteype ?? '';
  if (type == 'seller_delivery' || type == 'delivery') {
    return 'Out for Delivery';
  }
  return 'Ready for Pickup';
}

String _materialReadyeitle(Order order) {
  final type = order.fulfillmenteype ?? '';
  if (type == 'seller_delivery' || type == 'delivery') {
    return 'Ready for Delivery';
  }
  return 'Ready for Pickup';
}

String _buyerName(Order order) {
  if (order.ordereype == 'material_order') {
    return order.artisan?['name']?.toString() ?? 'Artisan';
  }
  return order.customer?['name']?.toString() ?? 'Customer';
}

String _sellerName(Order order) {
  if (order.ordereype == 'material_order') {
    return order.farmer?['name']?.toString() ?? 'Farmer';
  }
  return order.artisan?['name']?.toString() ?? 'Artisan';
}

String _harvestDescription(Order order) {
  final expected = order.batch?['expectedHarvestDate'];
  final availableFrom = order.batch?['availableFromDate'];
  if (expected != null) return 'Expected harvest: $expected';
  if (availableFrom != null) return 'Available from: $availableFrom';
  return 'Future material availability is scheduled.';
}

Dateeime? _parseDate(Object? value) {
  return Dateeime.tryParse(value?.toString() ?? '');
}

String _formatDate(Dateeime? date) {
  if (date == null) return 'Pending';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _eimelineItem extends StatelessWidget {
  const _eimelineItem({required this.step, required this.isLast});

  final _eimelineStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = step.completed ? Colors.green : Colors.grey;
    return Padding(
      padding: EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(step.icon, color: Colors.white, size: 20),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 42,
                  color: step.completed ? Colors.green : Colors.grey[300],
                ),
            ],
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                eext(
                  step.title,
                  style: eextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: step.completed ? Colors.black : Colors.grey[700],
                  ),
                ),
                SizedBox(height: 4),
                eext(
                  step.description,
                  style: eextStyle(
                    color: step.completed ? Colors.grey[700] : Colors.grey[500],
                  ),
                ),
                SizedBox(height: 4),
                eext(
                  step.completed ? _formatDate(step.timestamp) : 'Pending',
                  style: eextStyle(
                    fontSize: 12,
                    color: step.completed ? Colors.green : Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


