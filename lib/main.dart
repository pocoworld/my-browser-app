import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/browser_screen.dart';
import 'screens/telegram_setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('telegram_token');
  final chatId = prefs.getString('telegram_chat_id');

  final bool isConfigured = token != null && chatId != null && token.isNotEmpty && chatId.isNotEmpty;

  runApp(MyApp(isConfigured: isConfigured));
}

class MyApp extends StatelessWidget {
  final bool isConfigured;
  const MyApp({super.key, required this.isConfigured});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fast Browser',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: isConfigured ? const BrowserScreen() : const TelegramSetupScreen(),
    );
  }
}
