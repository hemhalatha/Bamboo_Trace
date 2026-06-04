import 'package:flutter/material.dart';

class ContactArtisanPage extends StatefulWidget {
  @override
  _ContactArtisanPageState createState() => _ContactArtisanPageState();
}

class _ContactArtisanPageState extends State<ContactArtisanPage> {
  final _messageController = TextEditingController();
  String _selectedArtisan = 'Raj Kumar';

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Message sent to $_selectedArtisan!')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Contact Artisan'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Artisan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedArtisan,
              decoration: InputDecoration(border: OutlineInputBorder()),
              items: ['Raj Kumar', 'Priya Singh', 'Kumar Das', 'Maya Devi']
                  .map((artisan) => DropdownMenuItem(value: artisan, child: Text(artisan)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedArtisan = val!),
            ),
            SizedBox(height: 20),
            Text('Your Message', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            TextField(
              controller: _messageController,
              maxLines: 6,
              decoration: InputDecoration(hintText: 'Describe your custom product requirements...', border: OutlineInputBorder()),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _sendMessage,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700]),
                child: Text('Send Message', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
