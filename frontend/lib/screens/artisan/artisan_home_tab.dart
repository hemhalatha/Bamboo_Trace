import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/error_messages.dart';
import 'add_project_page.dart';

class ArtisanHomeTab extends StatefulWidget {
  final VoidCallback? onOpenProducts;
  final VoidCallback? onOpenOrders;
  final VoidCallback? onOpenCustomerOrders;
  final VoidCallback? onOpenMaterialOrders;
  final VoidCallback? onOpenMarket;
  final VoidCallback? onOpenRequests;

  const ArtisanHomeTab({
    super.key,
    this.onOpenProducts,
    this.onOpenOrders,
    this.onOpenCustomerOrders,
    this.onOpenMaterialOrders,
    this.onOpenMarket,
    this.onOpenRequests,
  });

  @override
  State<ArtisanHomeTab> createState() => _ArtisanHomeTabState();
}

class _ArtisanHomeTabState extends State<ArtisanHomeTab> {
  final _apiService = ApiService();
  late Future<Map<String, dynamic>> _statsFuture;
  late Future<List<Map<String, dynamic>>> _projectsFuture;

  @override
  void initState() {
    super.initState();
    _loadHome();
  }

  void _loadHome() {
    _statsFuture = _apiService.getDashboardStats();
    _projectsFuture = _apiService.getProjects();
  }

  void _refreshHome() {
    setState(_loadHome);
  }

  Future<void> _openAddProduct() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddProjectPage()),
    );
    if (mounted) _refreshHome();
  }

  int _count(Map<String, dynamic> stats, String key) {
    final value = stats[key];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _textValue(Map<String, dynamic> project, String key, String fallback) {
    final value = project[key]?.toString().trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  String _status(Map<String, dynamic> project) {
    final value = project['status']?.toString().trim().toLowerCase();
    return value == null || value.isEmpty ? 'draft' : value;
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

  String _formatPrice(dynamic value) {
    final price = double.tryParse(value?.toString() ?? '');
    if (price == null || price <= 0) return 'Price not set';
    final amount = price == price.roundToDouble()
        ? price.toStringAsFixed(0)
        : price.toStringAsFixed(2);
    return 'INR $amount';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'available':
        return Color(0xFF246B45);
      case 'ordered':
        return Color(0xFFB26A00);
      case 'sold':
        return Color(0xFF596579);
      case 'archived':
        return Colors.grey;
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
                'Workshop dashboard',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF123D2A),
                    ),
              ),
              SizedBox(height: 8),
              Text(
                'Sell products, track customer work, and source bamboo without mixing the workflows.',
                style: TextStyle(color: Color(0xFF4C6254)),
              ),
            ],
          );
          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _openAddProduct,
                icon: Icon(Icons.add),
                label: Text('Add product'),
              ),
              OutlinedButton.icon(
                onPressed: widget.onOpenCustomerOrders ?? widget.onOpenOrders,
                icon: Icon(Icons.storefront),
                label: Text('Customer sales'),
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
        final productOrders = _count(stats, 'productOrdersReceived');
        final materialOrders = _count(stats, 'materialOrdersPlaced');
        final requests = _count(stats, 'activeCustomRequests');
        final alerts = _count(stats, 'unreadNotifications');
        final items = [
          _ActionData(
            '$productOrders customer sale${productOrders == 1 ? '' : 's'}',
            'Review product and custom orders from buyers.',
            Icons.storefront,
            widget.onOpenCustomerOrders ?? widget.onOpenOrders,
          ),
          _ActionData(
            '$materialOrders bamboo purchase${materialOrders == 1 ? '' : 's'}',
            'Track bamboo orders you place with farmers.',
            Icons.inventory_2,
            widget.onOpenMaterialOrders ?? widget.onOpenOrders,
          ),
          _ActionData(
            '$requests custom request${requests == 1 ? '' : 's'}',
            'Respond to made-to-order work.',
            Icons.assignment,
            widget.onOpenRequests,
          ),
          _ActionData(
            '$alerts unread alert${alerts == 1 ? '' : 's'}',
            'Check recent notifications from BambooTrace.',
            Icons.notifications,
            null,
          ),
        ];
        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 760 ? 1 : 4;
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

  Widget _buildMetrics() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return SizedBox.shrink();
        final stats = snapshot.data ?? {};
        final metrics = [
          _MetricData('Products', _count(stats, 'productsListed').toString(), Icons.storefront),
          _MetricData('Bamboo Purchases', _count(stats, 'materialOrdersPlaced').toString(), Icons.inventory_2),
          _MetricData('Customer Sales', _count(stats, 'productOrdersReceived').toString(), Icons.receipt_long),
          _MetricData('Requests', _count(stats, 'activeCustomRequests').toString(), Icons.assignment),
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

  Widget _buildRecentProducts() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _projectsFuture,
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
            title: 'Products could not load',
            message: friendlyErrorMessage(snapshot.error),
            action: TextButton(onPressed: _refreshHome, child: Text('Retry')),
          );
        }
        final projects = snapshot.data ?? [];
        if (projects.isEmpty) {
          return _messageCard(
            icon: Icons.add_business,
            title: 'No products listed yet',
            message: 'Add your first bamboo product so customers can discover it.',
            action: FilledButton.icon(
              onPressed: _openAddProduct,
              icon: Icon(Icons.add),
              label: Text('Add product'),
            ),
          );
        }
        return Column(
          children: projects.take(4).map((project) {
            final status = _status(project);
            final statusColor = _statusColor(status);
            return Card(
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                leading: CircleAvatar(
                  backgroundColor: Color(0xFFEAF4EC),
                  child: Icon(Icons.handyman, color: Color(0xFF246B45)),
                ),
                title: Text(
                  _textValue(project, 'productName', 'Bamboo product'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${_formatPrice(project['price'])} • ${_textValue(project, 'bambooType', 'Other / Unknown')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _formatStatus(status),
                    style: TextStyle(
                      color: statusColor,
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

  Widget _supplyStrip() {
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
                Text('Need more bamboo?', style: TextStyle(fontWeight: FontWeight.w800)),
                SizedBox(height: 3),
                Text(
                  'Open the material market to source bamboo from farmers.',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          TextButton(onPressed: widget.onOpenMarket, child: Text('Browse market')),
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
                _sectionHeader('Needs attention', 'Sales, sourcing, and requests that may need your next move.'),
                SizedBox(height: 12),
                _buildActionPanel(),
                SizedBox(height: 24),
                _sectionHeader(
                  'Recent products',
                  'Latest listings from your workshop.',
                  action: TextButton(
                    onPressed: widget.onOpenProducts,
                    child: Text('View all'),
                  ),
                ),
                SizedBox(height: 12),
                _buildRecentProducts(),
                SizedBox(height: 24),
                _supplyStrip(),
                SizedBox(height: 24),
                _sectionHeader('Business snapshot', 'Seller workspace counts at a glance.'),
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

