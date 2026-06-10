import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/order.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class RoleOrdersTab extends StatefulWidget {
  const RoleOrdersTab({
    super.key,
    required this.title,
    this.allowMaterialRequests = false,
  });

  final String title;
  final bool allowMaterialRequests;

  @override
  State<RoleOrdersTab> createState() => _RoleOrdersTabState();
}

class _RoleOrdersTabState extends State<RoleOrdersTab> {
  final _apiService = ApiService();
  late Future<List<Order>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _ordersFuture = _apiService.getOrderModels();
  }

  Future<void> _advanceStatus(Order order) async {
    final nextStatus = order.status == 'accepted' ? 'in_progress' : null;
    if (nextStatus == null || order.id == null) return;
    await _apiService.updateOrderStatus(order.id!, nextStatus);
    if (!mounted) return;
    setState(_reload);
  }

  bool _isReceiver(Order order, String? userId) {
    if (userId == null) return false;
    if (order.orderType == 'material_order') return order.artisanId == userId;
    return order.customerId == userId;
  }

  bool _isSeller(Order order, String? userId) {
    if (userId == null) return false;
    if (order.orderType == 'material_order') return order.farmerId == userId;
    return order.artisanId == userId;
  }

  Future<void> _generateOtp(Order order) async {
    if (order.id == null) return;
    try {
      final payload = await _apiService.generateHandoverOtp(order.id!);
      if (!mounted) return;
      setState(_reload);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Handover OTP'),
          content: SelectableText(
            '${payload['otp']}\nExpires: ${payload['expiresAt']}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _verifyOtp(Order order) async {
    if (order.id == null) return;
    final controller = TextEditingController();
    final otp = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Verify Handover'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(labelText: 'Receiver OTP'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text('Verify'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (otp == null || otp.isEmpty) return;
    try {
      await _apiService.verifyHandoverOtp(order.id!, otp);
      if (!mounted) return;
      setState(_reload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _confirmReceived(Order order) async {
    if (order.id == null) return;
    try {
      await _apiService.confirmOrderReceived(order.id!);
      if (!mounted) return;
      setState(_reload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _reportDispute(Order order) async {
    if (order.id == null) return;
    try {
      await _apiService.reportOrderDispute(order.id!);
      if (!mounted) return;
      setState(_reload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _requestMaterial(Order order) async {
    final batches = await _apiService.getBatchCatalog();
    if (!mounted) return;
    if (batches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No farmer batches available')),
      );
      return;
    }
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Select material batch'),
        children: batches.map((batch) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, batch),
            child: Text('${batch['batchId']} - ${batch['type']}'),
          );
        }).toList(),
      ),
    );
    if (selected == null || order.id == null) return;
    await _apiService.createOrderRequest(
      requestType: 'artisan_to_farmer',
      receiverId: selected['ownerId'] as String,
      orderId: order.id,
      batchId: selected['id'] as String,
      quantity: order.quantity,
      quantityUnit: 'kg',
      notes: 'Material needed for ${order.productName}',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Material request sent')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthService>().currentUser?.id;
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Order>>(
              future: _ordersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text(snapshot.error.toString()));
                }
                final orders = snapshot.data ?? [];
                if (orders.isEmpty) {
                  return Center(child: Text('No orders'));
                }
                return ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final isReceiver = _isReceiver(order, currentUserId);
                    final isSeller = _isSeller(order, currentUserId);
                    final isClosed = order.status == 'completed' ||
                        order.fulfillmentStatus == 'received' ||
                        order.fulfillmentStatus == 'disputed';
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    order.productName,
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Chip(label: Text(order.status.replaceAll('_', ' '))),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text('Quantity: ${order.quantity} ${order.quantityUnit}'),
                            Text(
                              'Fulfillment: ${order.fulfillmentStatus.replaceAll('_', ' ')}',
                            ),
                            if (order.notes != null && order.notes!.isNotEmpty)
                              Text(order.notes!),
                            SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (order.status == 'accepted')
                                  ElevatedButton(
                                    onPressed: () => _advanceStatus(order),
                                    child: Text('Start'),
                                  ),
                                if (isReceiver && !isClosed)
                                  OutlinedButton(
                                    onPressed: () => _generateOtp(order),
                                    child: Text('Generate OTP'),
                                  ),
                                if (isSeller && !isClosed)
                                  OutlinedButton(
                                    onPressed: () => _verifyOtp(order),
                                    child: Text('Verify OTP'),
                                  ),
                                if (isReceiver &&
                                    order.handoverVerifiedAt != null &&
                                    order.receiverConfirmedAt == null &&
                                    order.fulfillmentStatus != 'disputed')
                                  ElevatedButton(
                                    onPressed: () => _confirmReceived(order),
                                    child: Text('Confirm Received'),
                                  ),
                                if (isReceiver &&
                                    order.receiverConfirmedAt == null &&
                                    order.fulfillmentStatus != 'disputed')
                                  TextButton(
                                    onPressed: () => _reportDispute(order),
                                    child: Text('Report Dispute'),
                                  ),
                                if (widget.allowMaterialRequests && order.farmerId == null)
                                  OutlinedButton(
                                    onPressed: () => _requestMaterial(order),
                                    child: Text('Request Material'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
