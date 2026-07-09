import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/bamboo_types.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../utils/error_messages.dart';
import '../../utils/profile_completion_guard.dart';

class RoleOrdersTab extends StatefulWidget {
  const RoleOrdersTab({
    super.key,
    required this.title,
    this.allowMaterialRequests = false,
    this.initialArtisanOrderMode = 'customer_sales',
  });

  final String title;
  final bool allowMaterialRequests;
  final String initialArtisanOrderMode;

  @override
  State<RoleOrdersTab> createState() => _RoleOrdersTabState();
}

class _RoleOrdersTabState extends State<RoleOrdersTab> {
  final _apiService = ApiService();
  late Future<List<Order>> _ordersFuture;
  String _sortMode = 'newest';
  String _filterMode = 'all';
  late String _artisanOrderMode;
  final Set<String> _expandedOrderKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _artisanOrderMode = widget.initialArtisanOrderMode;
    _reload();
  }

  void _reload() {
    _ordersFuture = _apiService.getOrderModels();
  }

  Future<void> _refreshOrders() async {
    setState(_reload);
    await _ordersFuture;
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

  List<MapEntry<String, String>> _filterOptions() {
    return const [
      MapEntry('all', 'All'),
      MapEntry('active', 'Active'),
      MapEntry('handover', 'Handover'),
      MapEntry('closed', 'Closed'),
    ];
  }

  List<MapEntry<String, String>> _artisanOrderViews() {
    return const [
      MapEntry('customer_sales', 'Customer Sales'),
      MapEntry('bamboo_purchases', 'Bamboo Purchases'),
    ];
  }

  String _artisanOrderGroup(Order order) {
    return order.orderType == 'material_order'
        ? 'bamboo_purchases'
        : 'customer_sales';
  }

  List<Order> _ordersForArtisanView(List<Order> orders, String? role) {
    if (role != 'artisan') return orders;
    return orders
        .where((order) => _artisanOrderGroup(order) == _artisanOrderMode)
        .toList();
  }

  Map<String, int> _artisanViewCounts(List<Order> orders) {
    final counts = <String, int>{
      for (final option in _artisanOrderViews()) option.key: 0,
    };
    for (final order in orders) {
      final group = _artisanOrderGroup(order);
      counts[group] = (counts[group] ?? 0) + 1;
    }
    return counts;
  }

  String _artisanViewLabel() {
    return _artisanOrderViews()
        .firstWhere((option) => option.key == _artisanOrderMode)
        .value;
  }

  String _effectiveOrderState(Order order) {
    if (order.status == 'completed' ||
        order.status == 'handover_verified' ||
        order.completedAt != null ||
        order.receiverConfirmedAt != null ||
        order.handoverVerifiedAt != null ||
        order.fulfillmentStatus == 'received' ||
        order.fulfillmentStatus == 'handover_verified') {
      return 'completed';
    }

    switch (order.fulfillmentStatus) {
      case 'disputed':
        return 'disputed';
      case 'otp_generated':
        return 'otp_generated';
      default:
        return order.status.isEmpty ? 'pending' : order.status;
    }
  }

  String _filterGroupForOrder(Order order) {
    final state = _effectiveOrderState(order);
    switch (state) {
      case 'otp_generated':
        return 'handover';
      case 'handover_verified':
      case 'completed':
      case 'disputed':
      case 'rejected':
        return 'closed';
      default:
        return 'active';
    }
  }

  String _stateLabel(String state) {
    return switch (state) {
      'in_progress' => 'In Progress',
      'otp_generated' => 'OTP Generated',
      'handover_verified' => 'OTP Verified',
      'completed' => 'Completed',
      'disputed' => 'Disputed',
      'rejected' => 'Rejected',
      'accepted' => 'Accepted',
      'pending' => 'Pending',
      _ => 'Pending',
    };
  }

  Color _stateColor(String state) {
    return switch (state) {
      'accepted' => Colors.blue,
      'in_progress' => Colors.orange,
      'otp_generated' => Colors.deepPurple,
      'handover_verified' => Colors.teal,
      'completed' => Colors.green,
      'disputed' => Colors.red,
      'rejected' => Colors.grey,
      _ => Colors.blueGrey,
    };
  }

  List<Order> _filteredOrders(List<Order> orders) {
    if (_filterMode == 'all') return orders;
    return orders
        .where((order) => _filterGroupForOrder(order) == _filterMode)
        .toList();
  }

  Map<String, int> _filterCounts(List<Order> orders) {
    final counts = <String, int>{};
    for (final option in _filterOptions()) {
      counts[option.key] = option.key == 'all' ? orders.length : 0;
    }
    for (final order in orders) {
      final group = _filterGroupForOrder(order);
      counts[group] = (counts[group] ?? 0) + 1;
    }
    return counts;
  }

  String _pageSubtitle(String? role) {
    return switch (role) {
      'customer' => 'Track purchases, handovers, and completed orders.',
      'artisan' => 'Separate customer sales from bamboo purchases.',
      'farmer' => 'Manage bamboo material orders and handovers.',
      _ => 'Track and manage orders.',
    };
  }

  List<MapEntry<String, String>> _sortOptions(String? role) {
    final counterpartLabel = switch (role) {
      'customer' => 'Seller name',
      'farmer' => 'Artisan name',
      'artisan' => 'Customer / farmer name',
      _ => 'Counterparty name',
    };
    return [
      MapEntry('newest', 'Newest first'),
      MapEntry('oldest', 'Oldest first'),
      MapEntry('status', 'Status'),
      MapEntry('counterparty', counterpartLabel),
    ];
  }

  String _counterpartyName(Order order, String? role) {
    if (role == 'customer' || role == 'farmer') {
      return order.artisan?['name']?.toString() ?? '';
    }
    if (role == 'artisan') {
      if (order.orderType == 'material_order') {
        return order.farmer?['name']?.toString() ?? '';
      }
      return order.customer?['name']?.toString() ?? '';
    }
    return '';
  }

  List<Order> _sortedOrders(List<Order> orders, String? role) {
    final sorted = List<Order>.from(orders);
    switch (_sortMode) {
      case 'oldest':
        sorted.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'status':
        sorted.sort(
          (a, b) => _effectiveOrderState(
            a,
          ).compareTo(_effectiveOrderState(b)),
        );
        break;
      case 'counterparty':
        sorted.sort(
          (a, b) => _counterpartyName(
            a,
            role,
          ).toLowerCase().compareTo(_counterpartyName(b, role).toLowerCase()),
        );
        break;
      case 'newest':
      default:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return sorted;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _partyLabel(Order order, String? currentRole) {
    if (currentRole == 'farmer' && order.orderType == 'material_order') {
      final name = order.artisan?['name'] ?? 'Artisan buyer';
      final email = order.artisan?['email'];
      return email == null ? 'Buyer: $name' : 'Buyer: $name ($email)';
    }
    if (currentRole == 'artisan' && order.orderType == 'material_order') {
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
          Text(
            '$label: ${_nameFromUser(user, fallbackName)}',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          if (phone != null && phone.isNotEmpty) Text('Phone: $phone'),
          if (email != null && email.isNotEmpty) Text('Email: $email'),
          Text('Address: ${_addressFromUser(user)}'),
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
      final otp = payload['otp']?.toString() ?? '';
      final expiresAt = payload['expiresAt']?.toString() ?? 'expiry not available';
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Share handover OTP'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Give this OTP to the seller only during handover.',
                style: TextStyle(color: Colors.grey[700]),
              ),
              SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.35),
                  ),
                ),
                child: SelectableText(
                  otp,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                ),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.schedule, size: 18, color: Colors.grey[700]),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Expires: $expiresAt',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: otp.isEmpty
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(text: otp));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('OTP copied')),
                      );
                    },
              icon: Icon(Icons.copy),
              label: Text('Copy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
      );
    }
  }

  Future<void> _verifyOtp(Order order) async {
    if (order.id == null) return;
    final controller = TextEditingController();
    final otp = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter receiver OTP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ask the receiver to generate and share their current handover OTP.',
              style: TextStyle(color: Colors.grey[700]),
            ),
            SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              decoration: InputDecoration(
                labelText: '6-digit OTP',
                helperText: 'Use the latest unexpired OTP from the receiver.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text('Verify handover'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (otp == null || otp.isEmpty) return;
    try {
      await _apiService.verifyHandoverOtp(order.id!, otp);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Handover verified. Order completed.')),
      );
      setState(_reload);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
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
        SnackBar(content: Text(friendlyErrorMessage(e))),
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
      ).showSnackBar(SnackBar(content: Text('No farmer batches available')));
      return;
    }
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Select material batch'),
        children: batches.map((batch) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, batch),
            child: Text(
              '${batch['batchId']} - ${displayBambooType(batch['type'])}',
            ),
          );
        }).toList(),
      ),
    );
    if (selected == null || order.id == null) return;
    try {
      await _apiService.createOrderRequest(
        requestType: 'artisan_to_farmer',
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
        SnackBar(content: Text(friendlyErrorMessage(e))),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Material request sent')));
  }

  Widget _buildArtisanOrderSwitcher(List<Order> orders) {
    final counts = _artisanViewCounts(orders);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFF3F8F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0xFFDCE8D9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order workspace',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _artisanOrderViews().map((option) {
                final selected = _artisanOrderMode == option.key;
                final count = counts[option.key] ?? 0;
                return Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('${option.value} ($count)'),
                    selected: selected,
                    avatar: Icon(
                      option.key == 'customer_sales'
                          ? Icons.storefront
                          : Icons.inventory_2,
                      size: 18,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _artisanOrderMode = option.key;
                        _filterMode = 'all';
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 8),
          Text(
            _artisanOrderMode == 'customer_sales'
                ? 'Orders customers place for your bamboo products and custom work.'
                : 'Bamboo material orders you place with farmers.',
            style: TextStyle(color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(List<Order> orders) {
    final counts = _filterCounts(orders);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _filterOptions().map((option) {
          final selected = _filterMode == option.key;
          return Padding(
            padding: EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${option.value} (${counts[option.key] ?? 0})'),
              selected: selected,
              onSelected: (_) => setState(() => _filterMode = option.key),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusBadge(Order order) {
    final state = _effectiveOrderState(order);
    final color = _stateColor(state);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        _stateLabel(state),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 42, color: Colors.red[700]),
            SizedBox(height: 12),
            Text(
              'Unable to load orders',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text(friendlyErrorMessage(error), textAlign: TextAlign.center),
            SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => setState(_reload),
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required bool hasAnyOrders,
    String? contextLabel,
  }) {
    final selectedLabel = _filterOptions()
        .firstWhere((option) => option.key == _filterMode)
        .value;
    final emptyLabel = contextLabel ?? 'orders';
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 44, color: Colors.grey[600]),
            SizedBox(height: 12),
            Text(
              hasAnyOrders
                  ? 'No $selectedLabel orders'
                  : contextLabel == null
                      ? 'No orders yet'
                      : 'No $emptyLabel yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text(
              hasAnyOrders
                  ? 'Choose another filter to see your other orders.'
                  : contextLabel == null
                      ? 'Orders will appear here when activity begins.'
                      : 'This section will fill when matching orders are created.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
            if (hasAnyOrders) ...[
              SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => setState(() => _filterMode = 'all'),
                child: Text('Show all orders'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _orderKey(Order order, int index) {
    if (order.id != null && order.id!.isNotEmpty) return order.id!;
    return '${order.orderType}-${order.productName}-$index-${order.createdAt.toIso8601String()}';
  }

  String _orderTitle(Order order) {
    final name = order.productName.trim();
    if (name.isNotEmpty) return name;
    return order.orderType == 'material_order'
        ? 'Bamboo material order'
        : 'Product order';
  }

  String _readableValue(String value) {
    return value.replaceAll('_', ' ');
  }

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderActions({
    required Order order,
    required bool isReceiver,
    required bool isSeller,
    required bool isClosed,
    required bool otpVerified,
    required bool hasActiveOtp,
  }) {
    final actions = <Widget>[
      if (isSeller && order.status == 'accepted')
        ElevatedButton(
          onPressed: () => _advanceStatus(order),
          child: Text('Start'),
        ),
      if (isReceiver && !isClosed && !otpVerified)
        OutlinedButton(
          onPressed: () => _generateOtp(order),
          child: Text(hasActiveOtp ? 'Generate new OTP' : 'Get handover OTP'),
        ),
      if (isSeller && !isClosed && hasActiveOtp)
        OutlinedButton(
          onPressed: () => _verifyOtp(order),
          child: Text('Enter OTP'),
        ),
      if (isSeller && !isClosed && !hasActiveOtp && !otpVerified)
        Chip(label: Text('Ask receiver for OTP')),
      if (otpVerified) Chip(label: Text('Handover OTP verified')),
      if (isReceiver &&
          !otpVerified &&
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
    ];

    if (actions.isEmpty) {
      return Text(
        'No actions available for this order.',
        style: TextStyle(color: Colors.grey[700]),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actions,
    );
  }

  Widget _buildOrderCard({
    required Order order,
    required int index,
    required String? currentUserId,
    required String? currentRole,
  }) {
    final orderKey = _orderKey(order, index);
    final expanded = _expandedOrderKeys.contains(orderKey);
    final isReceiver = _isReceiver(order, currentUserId);
    final isSeller = _isSeller(order, currentUserId);
    final contact = _otherPartyContact(order, currentUserId, currentRole);
    final isClosed = order.status == 'completed' ||
        order.completedAt != null ||
        order.receiverConfirmedAt != null ||
        order.handoverVerifiedAt != null ||
        order.fulfillmentStatus == 'received' ||
        order.fulfillmentStatus == 'handover_verified' ||
        order.fulfillmentStatus == 'disputed';
    final otpVerified = order.handoverVerifiedAt != null ||
        order.fulfillmentStatus == 'handover_verified';
    final hasActiveOtp = !otpVerified &&
        order.handoverOtpExpiresAt != null &&
        order.fulfillmentStatus == 'otp_generated';

    void toggleExpanded() {
      setState(() {
        if (expanded) {
          _expandedOrderKeys.remove(orderKey);
        } else {
          _expandedOrderKeys.add(orderKey);
        }
      });
    }

    return Card(
      margin: EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: toggleExpanded,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _orderTitle(order),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 8),
                            _buildStatusBadge(order),
                          ],
                        ),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          children: [
                            Text(
                              _partyLabel(order, currentRole),
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            Text(
                              _formatDate(order.createdAt),
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            Text(
                              '${order.quantity} ${order.quantityUnit}',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    tooltip: expanded ? 'Hide order details' : 'Show order details',
                    onPressed: toggleExpanded,
                    icon: Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: SizedBox.shrink(),
            secondChild: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(height: 1),
                  SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildStatusBadge(order),
                      Chip(
                        label: Text(_readableValue(order.orderType)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Order details',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth < 520 ? 1 : 2;
                      final width = (constraints.maxWidth - ((columns - 1) * 16)) / columns;
                      final details = <Widget>[
                        _detailLine('Party', _partyLabel(order, currentRole)),
                        _detailLine(
                          'Quantity',
                          '${order.quantity} ${order.quantityUnit}',
                        ),
                        if (order.fulfillmentType != null)
                          _detailLine(
                            'Fulfillment type',
                            _readableValue(order.fulfillmentType!),
                          ),
                        _detailLine(
                          'Fulfillment status',
                          _readableValue(order.fulfillmentStatus),
                        ),
                        _detailLine('Order date', _formatDate(order.createdAt)),
                      ];
                      return Wrap(
                        spacing: 16,
                        runSpacing: 4,
                        children: details
                            .map((detail) => SizedBox(width: width, child: detail))
                            .toList(),
                      );
                    },
                  ),
                  if (order.notes != null && order.notes!.isNotEmpty) ...[
                    SizedBox(height: 8),
                    _detailLine('Notes', order.notes!),
                  ],
                  SizedBox(height: 8),
                  Text(
                    'Contact',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  _contactDetails(
                    label: contact.label,
                    user: contact.user,
                    fallbackName: contact.fallbackName,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Actions',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  _buildOrderActions(
                    order: order,
                    isReceiver: isReceiver,
                    isSeller: isSeller,
                    isClosed: isClosed,
                    otpVerified: otpVerified,
                    hasActiveOtp: hasActiveOtp,
                  ),
                ],
              ),
            ),
            crossFadeState:
                expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: Duration(milliseconds: 180),
          ),
        ],
      ),
    );
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
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              return Wrap(
                alignment: WrapAlignment.spaceBetween,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: compact
                        ? constraints.maxWidth
                        : constraints.maxWidth - 240,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        SizedBox(height: 4),
                        Text(
                          _pageSubtitle(currentRole),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: compact ? constraints.maxWidth : 220,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Sort by',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _sortMode,
                          isExpanded: true,
                          isDense: true,
                          items: _sortOptions(currentRole)
                              .map(
                                (option) => DropdownMenuItem(
                                  value: option.key,
                                  child: Text(
                                    option.value,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _sortMode = value);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
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
                  return _buildErrorState(snapshot.error);
                }
                final allOrders = snapshot.data ?? [];
                final ordersInView = _ordersForArtisanView(
                  allOrders,
                  currentRole,
                );
                final orders = _sortedOrders(
                  _filteredOrders(ordersInView),
                  currentRole,
                );
                final contextLabel = currentRole == 'artisan'
                    ? _artisanViewLabel()
                    : null;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (currentRole == 'artisan') ...[
                      _buildArtisanOrderSwitcher(allOrders),
                      SizedBox(height: 14),
                    ],
                    Text(
                      'Filter by status',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    SizedBox(height: 8),
                    _buildFilterChips(ordersInView),
                    SizedBox(height: 12),
                    Expanded(
                      child: orders.isEmpty
                          ? _buildEmptyState(
                              hasAnyOrders: ordersInView.isNotEmpty,
                              contextLabel: contextLabel,
                            )
                          : RefreshIndicator(
                              onRefresh: _refreshOrders,
                              child: ListView.builder(
                                  itemCount: orders.length,
                                  itemBuilder: (context, index) {
                                    final order = orders[index];
                                    return _buildOrderCard(
                                      order: order,
                                      index: index,
                                      currentUserId: currentUserId,
                                      currentRole: currentRole,
                                    );
                                  },
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
