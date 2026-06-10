import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'notifications_page.dart';

class NotificationIconButton extends StatefulWidget {
  const NotificationIconButton({super.key});

  @override
  State<NotificationIconButton> createState() => _NotificationIconButtonState();
}

class _NotificationIconButtonState extends State<NotificationIconButton> {
  final _apiService = ApiService();
  late Future<int> _countFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _countFuture = _apiService.getUnreadNotificationCount();
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NotificationsPage()),
    );
    if (!mounted) return;
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _countFuture,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.notifications),
              onPressed: _openNotifications,
            ),
            if (count > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  constraints: BoxConstraints(minWidth: 18, minHeight: 18),
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: Text(
                      count > 99 ? '99+' : count.toString(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
