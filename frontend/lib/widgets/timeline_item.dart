import 'package:flutter/material.dart';

class TimelineItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final DateTime time;
  final Color? dotColor;

  const TimelineItem({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.time,
    this.dotColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(right: 12, top: 6),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor ?? Colors.green[700],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: Colors.grey[700])),
              SizedBox(height: 4),
              Text(
                "${time.toLocal()}".split('.')[0], // simple datetime string
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}
