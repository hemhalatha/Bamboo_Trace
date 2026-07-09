import 'package:flutter/material.dart';

import '../../models/app_notification.dart';
import '../../models/order.dart';
import '../../services/api_service.dart';
import '../../utils/error_messages.dart';
import 'add_batch_page.dart';

class FarmerHomeTab extends StatefulWidget {
  final VoidCallback? onOpenRequests;
  final VoidCallback? onOpenOrders;
  final VoidCallback? onOpenBatches;

  const FarmerHomeTab({
    super.key,
    this.onOpenRequests,
    this.onOpenOrders,
    this.onOpenBatches,
  });

  @override
  State<FarmerHomeTab> createState() => _FarmerHomeTabState();
}

class _FarmerHomeTabState extends State<FarmerHomeTab> {
  final _apiService = ApiService();
  late Future<Map<String, dynamic>> _statsFuture;
  late Future<List<Order>> _ordersFuture;
  late Future<List<AppNotification>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _loadHome();
  }

  void _loadHome() {
    _statsFuture = _apiService.getDashboardStats();
    _ordersFuture = _apiService.getOrderModels();
    _notificationsFuture = _apiService.getNotifications();
  }

  void _refreshHome() {
    setState(_loadHome);
  }

  Future<void> _openAddBatch() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddBatchPage()),
    );
    if (mounted) _refreshHome();
  }

  int _count(Map<String, dynamic> stats, String key) {
    final value = stats[key];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatStatus(String status) {
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  String _buyerName(Order order) {
    final artisan = order.artisan?['name']?.toString().trim();
    if (artisan != null && artisan.isNotEmpty) return artisan;
    final customer = order.customer?['name']?.toString().trim();
    if (customer != null && customer.isNotEmpty) return customer;
    return 'Buyer';
  }

  bool _isActiveOrder(Order order) {
    return order.status != 'completed' &&
        order.fulfillmentStatus != 'received' &&
        order.fulfillmentStatus != 'disputed';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
      case 'in_progress':
      case 'handover_verified':
        return Color(0xFF246B45);
      case 'pending':
      case 'pending_handover':
      case 'otp_generated':
        return Color(0xFFB26A00);
      case 'rejected':
      case 'disputed':
        return Color(0xFFB3261E);
      default:
        return Colors.blueGrey;
    }
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFFEAF4EC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Color(0xFFD5E8D9)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 640;
          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bamboo supply dashboard',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF123D2A),
                    ),
              ),
              SizedBox(height: 8),
              Text(
                'List harvest batches, handle material orders, and keep artisans supplied.',
                style: TextStyle(color: Color(0xFF4C6254)),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _openAddBatch,
                icon: Icon(Icons.add),
                label: Text('Add batch'),
              ),
              OutlinedButton.icon(
                onPressed: widget.onOpenOrders,
                icon: Icon(Icons.shopping_bag),
                label: Text('Orders'),
              ),
            ],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [text, SizedBox(height: 16), actions],
            );
          }
          return Row(
            children: [
              Expanded(child: text),
              SizedBox(width: 24),
              actions,
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionPanel() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return LinearProgressIndicator(minHeight: 2);
        }
        if (snapshot.hasError) {
          return _messageCard(
            icon: Icons.error_outline,
            title: 'Dashboard could not load',
            message: friendlyErrorMessage(snapshot.error),
            action: TextButton(onPressed: _refreshHome, child: Text('Retry')),
          );
        }
        final stats = snapshot.data ?? {};
        final materialOrders = _count(stats, 'materialOrdersReceived');
        final activeOrders = _count(stats, 'activeMaterialOrders');
        final alerts = _count(stats, 'unreadNotifications');
        final items = [
          _ActionData(
            '$materialOrders material order${materialOrders == 1 ? '' : 's'}',
            'Review requests from artisans.',
            Icons.receipt_long,
            widget.onOpenRequests,
          ),
          _ActionData(
            '$activeOrders active order${activeOrders == 1 ? '' : 's'}',
            'Continue fulfillment and handover work.',
            Icons.handshake,
            widget.onOpenOrders,
          ),
          _ActionData(
            '$alerts unread alert${alerts == 1 ? '' : 's'}',
            'Recent updates from BambooTrace.',
            Icons.notifications,
            null,
          ),
        ];
        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 760 ? 1 : 3;
            final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: items.map((item) => SizedBox(
                width: width,
                child: _actionTile(item),
              )).toList(),
            );
          },
        );
      },
    );
  }

  Widget _actionTile(_ActionData item) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0xFFE0E6DF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: Color(0xFFEAF4EC),
            child: Icon(item.icon, color: Color(0xFF246B45)),
          ),
          SizedBox(height: 12),
          Text(item.title, style: TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Text(item.subtitle, style: TextStyle(color: Colors.grey[700])),
          if (item.onTap != null) ...[
            SizedBox(height: 10),
            TextButton(onPressed: item.onTap, child: Text('Open')),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveOrders() {
    return FutureBuilder<List<Order>>(
      future: _ordersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError) {
          return _messageCard(
            icon: Icons.wifi_off,
            title: 'Orders could not load',
            message: friendlyErrorMessage(snapshot.error),
            action: TextButton(onPressed: _refreshHome, child: Text('Retry')),
          );
        }
        final activeOrders = (snapshot.data ?? []).where(_isActiveOrder).take(4).toList();
        if (activeOrders.isEmpty) {
          return _messageCard(
            icon: Icons.handshake,
            title: 'No active material orders',
            message: 'New artisan orders will appear here when they need action.',
          );
        }
        return Column(
          children: activeOrders.map((order) {
            final effectiveStatus = order.fulfillmentStatus == 'pending_handover'
                ? order.status
                : order.fulfillmentStatus;
            final color = _statusColor(effectiveStatus);
            return Card(
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                leading: CircleAvatar(
                  backgroundColor: Color(0xFFEAF4EC),
                  child: Icon(Icons.grass, color: Color(0xFF246B45)),
                ),
                title: Text(
                  order.productName.isEmpty ? 'Bamboo material order' : order.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${_buyerName(order)} • ${order.quantity} ${order.quantityUnit} • ${_formatDate(order.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _formatStatus(effectiveStatus),
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildMetrics() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox.shrink();
        final stats = snapshot.data ?? {};
        final metrics = [
          _MetricData('Batches', _count(stats, 'batchesListed').toString(), Icons.inventory),
          _MetricData('Upcoming', _count(stats, 'upcomingBatches').toString(), Icons.event),
          _MetricData('Orders', _count(stats, 'materialOrdersReceived').toString(), Icons.receipt_long),
          _MetricData('Active', _count(stats, 'activeMaterialOrders').toString(), Icons.pending_actions),
        ];
        return _metricWrap(metrics);
      },
    );
  }

  Widget _metricWrap(List<_MetricData> metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 460 ? 2 : 4;
        final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: metrics.map((metric) => SizedBox(
            width: width,
            child: Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Color(0xFFE0E6DF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(metric.icon, size: 20, color: Color(0xFF246B45)),
                  SizedBox(height: 10),
                  Text(
                    metric.value,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  Text(
                    metric.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey[700], fontSize: 12),
                  ),
                ],
              ),
            ),
          )).toList(),
        );
      },
    );
  }

  Widget _buildRecentActivity() {
    return FutureBuilder<List<AppNotification>>(
      future: _notificationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError) {
          return _messageCard(
            icon: Icons.wifi_off,
            title: 'Activity could not load',
            message: friendlyErrorMessage(snapshot.error),
            action: TextButton(onPressed: _refreshHome, child: Text('Retry')),
          );
        }
        final notifications = snapshot.data ?? [];
        if (notifications.isEmpty) {
          return _messageCard(
            icon: Icons.notifications,
            title: 'No recent activity',
            message: 'Notifications and order updates will appear here.',
          );
        }
        return Column(
          children: notifications.take(3).map((notification) {
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: notification.readAt == null
                      ? Color(0xFFFFF6E0)
                      : Color(0xFFEAF4EC),
                  child: Icon(
                    notification.readAt == null
                        ? Icons.notifications_active
                        : Icons.notifications,
                    color: notification.readAt == null
                        ? Color(0xFF8A5A00)
                        : Color(0xFF246B45),
                  ),
                ),
                title: Text(
                  notification.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  notification.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _batchStrip() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFF6F1E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFE9DEC8)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Color(0xFFE7D7B9),
            child: Icon(Icons.inventory_2, color: Color(0xFF6D4B16)),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Keep your stock visible', style: TextStyle(fontWeight: FontWeight.w800)),
                SizedBox(height: 3),
                Text(
                  'Update bamboo batches so artisans know what is ready to buy.',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          TextButton(onPressed: widget.onOpenBatches, child: Text('Batches')),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle, {Widget? action}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: Colors.grey[700])),
            ],
          ),
        ),
        if (action != null) action,
      ],
    );
  }

  Widget _messageCard({
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Color(0xFFEAF4EC),
              child: Icon(icon, color: Color(0xFF246B45)),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text(message, style: TextStyle(color: Colors.grey[700])),
                  if (action != null) ...[
                    SizedBox(height: 10),
                    action,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _refreshHome(),
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 1080),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHero(),
                SizedBox(height: 20),
                _sectionHeader('Action needed', 'Material supply work that may need attention.'),
                SizedBox(height: 12),
                _buildActionPanel(),
                SizedBox(height: 24),
                _sectionHeader(
                  'Active material orders',
                  'Recent orders that are still moving through fulfillment.',
                  action: TextButton(
                    onPressed: widget.onOpenOrders,
                    child: Text('View all'),
                  ),
                ),
                SizedBox(height: 12),
                _buildActiveOrders(),
                SizedBox(height: 24),
                _batchStrip(),
                SizedBox(height: 24),
                _sectionHeader('Recent activity', 'Latest alerts and order updates.'),
                SizedBox(height: 12),
                _buildRecentActivity(),
                SizedBox(height: 24),
                _sectionHeader('Supply snapshot', 'Compact counts for your farm dashboard.'),
                SizedBox(height: 12),
                _buildMetrics(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricData {
  final String label;
  final String value;
  final IconData icon;

  const _MetricData(this.label, this.value, this.icon);
}

class _ActionData {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  const _ActionData(this.title, this.subtitle, this.icon, this.onTap);
}
