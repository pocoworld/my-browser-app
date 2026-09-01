import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'browser_screen.dart';

class TelegramSetupScreen extends StatefulWidget {
  const TelegramSetupScreen({super.key});

  @override
  State<TelegramSetupScreen> createState() => _TelegramSetupScreenState();
}

class _TelegramSetupScreenState extends State<TelegramSetupScreen> {
  final _tokenController = TextEditingController();
  final _chatIdController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveAndContinue() async {
    final token = _tokenController.text.trim();
    final chatId = _chatIdController.text.trim();

    if (token.isEmpty || chatId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('telegram_token', token);
    await prefs.setString('telegram_chat_id', chatId);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const BrowserScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('One-Time Setup')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.send_rounded, size: 70, color: Colors.blueAccent),
            const SizedBox(height: 20),
            const Text(
              'Telegram Sync Setup',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Enter your Telegram Bot Token and Chat ID to sync files.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Telegram Bot Token',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _chatIdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Telegram Chat ID',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveAndContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save & Open Browser', style: TextStyle(fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
