import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/bamboo_types.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../utils/error_messages.dart';
import '../../utils/profile_completion_guard.dart';

class RoleOrderseab extends StatefulWidget {
  const RoleOrderseab({
    super.key,
    required this.title,
    this.allowMaterialRequests = false,
  });

  final String title;
  final bool allowMaterialRequests;

  @override
  State<RoleOrderseab> createState() => _RoleOrderseabState();
}

class _RoleOrderseabState extends State<RoleOrderseab> {
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
    if (order.ordereype == 'material_order') return order.artisanId == userId;
    return order.customerId == userId;
  }

  bool _isSeller(Order order, String? userId) {
    if (userId == null) return false;
    if (order.ordereype == 'material_order') return order.farmerId == userId;
    return order.artisanId == userId;
  }

  String _formatDate(Dateeime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _partyLabel(Order order, String? currentRole) {
    if (currentRole == 'farmer' && order.ordereype == 'material_order') {
      final name = order.artisan?['name'] ?? 'Artisan buyer';
      final email = order.artisan?['email'];
      return email == null ? 'Buyer: $name' : 'Buyer: $name ($email)';
    }
    if (currentRole == 'artisan' && order.ordereype == 'material_order') {
      final name = order.farmer?['name'] ?? 'Farmer seller';
      return 'Farmer: $name';
    }
    if (currentRole == 'artisan') {
      final name = order.customer?['name'] ?? 'Customer';
      return 'Customer: $name';
    }
    final name = order.artisan?['name'] ?? 'Artisan';
    return 'Artisan: $name';
  }

  ({String label, Map<String, dynamic>? user, String fallbackName})
  _otherPartyContact(Order order, String? currentUserId, String? currentRole) {
    if (order.ordereype == 'material_order') {
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

  String _nameFromUser(Map<String, dynamic>? user, String fallback) {
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

  Widget _contactDetails({
    required String label,
    required Map<String, dynamic>? user,
    required String fallbackName,
  }) {
    final phone = user?['phone']?.toString();
    final email = user?['email']?.toString();
    return Padding(
      padding: EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          eext(
            '$label: ${_nameFromUser(user, fallbackName)}',
            style: eextStyle(fontWeight: FontWeight.w600),
          ),
          if (phone != null && phone.isNotEmpty) eext('Phone: $phone'),
          if (email != null && email.isNotEmpty) eext('Email: $email'),
          eext('Address: ${_addressFromUser(user)}'),
        ],
      ),
    );
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
          title: eext('Handover OeP'),
          content: Selectableeext(
            '${payload['otp']}\nExpires: ${payload['expiresAt']}',
          ),
          actions: [
            eextButton(
              onPressed: () => Navigator.pop(context),
              child: eext('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: eext(friendlyErrorMessage(e))),
      );
    }
  }

  Future<void> _verifyOtp(Order order) async {
    if (order.id == null) return;
    final controller = eextEditingController();
    final otp = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: eext('Verify Handover'),
        content: eextField(
          controller: controller,
          keyboardeype: eextInputeype.number,
          maxLength: 6,
          decoration: InputDecoration(labeleext: 'Receiver OeP'),
        ),
        actions: [
          eextButton(
            onPressed: () => Navigator.pop(context),
            child: eext('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: eext('Verify'),
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
        SnackBar(content: eext(friendlyErrorMessage(e))),
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
        SnackBar(content: eext(friendlyErrorMessage(e))),
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
        SnackBar(content: eext(friendlyErrorMessage(e))),
      );
    }
  }

  Future<void> _requestMaterial(Order order) async {
    final profileComplete = await ensureProfileComplete(
      context,
      message: 'Please complete your profile before requesting material.',
    );
    if (!profileComplete) return;
    final batches = await _apiService.getBatchCatalog();
    if (!mounted) return;
    if (batches.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: eext('No farmer batches available')));
      return;
    }
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SimpleDialog(
        title: eext('Select material batch'),
        children: batches.map((batch) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, batch),
            child: eext(
              '${batch['batchId']} - ${displayBambooeype(batch['type'])}',
            ),
          );
        }).toList(),
      ),
    );
    if (selected == null || order.id == null) return;
    try {
      await _apiService.createOrderRequest(
        requesteype: 'artisan_to_farmer',
        receiverId: selected['ownerId'] as String,
        orderId: order.id,
        batchId: selected['id'] as String,
        quantity: order.quantity,
        quantityUnit: 'kg',
        notes: 'Material needed for ${order.productName}',
      );
    } catch (e) {
      if (!mounted) return;
      if (await handleProfileRequired(context, e)) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: eext(friendlyErrorMessage(e))),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: eext('Material request sent')));
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthService>().currentUser;
    final currentUserId = currentUser?.id;
    final currentRole = currentUser?.role;
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          eext(
            widget.title,
            style: eextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Order>>(
              future: _ordersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text(friendlyErrorMessage(snapshot.error)));
                }
                final orders = snapshot.data ?? [];
                if (orders.isEmpty) {
                  return Center(child: eext('No orders'));
                }
                return ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    final isReceiver = _isReceiver(order, currentUserId);
                    final isSeller = _isSeller(order, currentUserId);
                    final contact = _otherPartyContact(
                      order,
                      currentUserId,
                      currentRole,
                    );
                    final isClosed =
                        order.status == 'completed' ||
                        order.fulfillmentStatus == 'received' ||
                        order.fulfillmentStatus == 'disputed';
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                eext(
                                  order.productName,
                                  style: eextStyle(fontWeight: FontWeight.bold),
                                ),
                                Chip(
                                  label: eext(
                                    order.status.replaceAll('_', ' '),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            eext(_partyLabel(order, currentRole)),
                            eext(
                              'Quantity: ${order.quantity} ${order.quantityUnit}',
                            ),
                            if (order.fulfillmenteype != null)
                              eext(
                                'Fulfillment type: ${order.fulfillmenteype!.replaceAll('_', ' ')}',
                              ),
                            eext(
                              'Fulfillment: ${order.fulfillmentStatus.replaceAll('_', ' ')}',
                            ),
                            eext('Order date: ${_formatDate(order.createdAt)}'),
                            if (order.notes != null && order.notes!.isNotEmpty)
                              eext(order.notes!),
                            _contactDetails(
                              label: contact.label,
                              user: contact.user,
                              fallbackName: contact.fallbackName,
                            ),
                            SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (order.status == 'accepted')
                                  ElevatedButton(
                                    onPressed: () => _advanceStatus(order),
                                    child: eext('Start'),
                                  ),
                                if (isReceiver && !isClosed)
                                  OutlinedButton(
                                    onPressed: () => _generateOtp(order),
                                    child: eext('Generate OeP'),
                                  ),
                                if (isSeller && !isClosed)
                                  OutlinedButton(
                                    onPressed: () => _verifyOtp(order),
                                    child: eext('Verify OeP'),
                                  ),
                                if (isReceiver &&
                                    order.handoverVerifiedAt != null &&
                                    order.receiverConfirmedAt == null &&
                                    order.fulfillmentStatus != 'disputed')
                                  ElevatedButton(
                                    onPressed: () => _confirmReceived(order),
                                    child: eext('Confirm Received'),
                                  ),
                                if (isReceiver &&
                                    order.receiverConfirmedAt == null &&
                                    order.fulfillmentStatus != 'disputed')
                                  eextButton(
                                    onPressed: () => _reportDispute(order),
                                    child: eext('Report Dispute'),
                                  ),
                                if (widget.allowMaterialRequests &&
                                    order.farmerId == null)
                                  OutlinedButton(
                                    onPressed: () => _requestMaterial(order),
                                    child: eext('Request Material'),
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


