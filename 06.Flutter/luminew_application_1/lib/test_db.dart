import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mysql1/mysql1.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(title: "MySQL 連線測試", home: TestPage());
  }
}

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  _TestPageState createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  String status = "尚未連線";
  MySqlConnection? _conn;

  // 1. 連線測試
  Future<void> connect() async {
    setState(() => status = "連線中...");

    var settings = ConnectionSettings(
      host: '10.0.2.2', // 模擬器連電腦 IP
      port: 3306,
      user: 'root',
      password: '',
      db: 'LuminewDB',
    );

    try {
      _conn = await MySqlConnection.connect(settings);
      setState(() => status = "✅ MySQL 連線成功！");
      print("Connected!");
    } catch (e) {
      setState(() => status = "❌ 連線失敗：\n$e");
      print(e);
    }
  }

  // 2. 讀取測試
  Future<void> read() async {
    if (_conn == null) {
      setState(() => status = "⚠️ 請先連線");
      return;
    }
    try {
      var results = await _conn!.query('SELECT * FROM Users');
      String display = "";
      if (results.isEmpty) {
        display = "資料表是空的";
      } else {
        for (var row in results) {
          display += "ID: ${row['UserID']}, Name: ${row['Name']}\n";
        }
      }
      setState(() => status = "讀取資料成功：\n$display");
    } catch (e) {
      setState(() => status = "讀取失敗：$e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MySQL 測試'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              status,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 30),
            ElevatedButton(onPressed: connect, child: const Text("1. 連線")),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: read, child: const Text("2. 讀取 Users")),
          ],
        ),
      ),
    );
  }
}
