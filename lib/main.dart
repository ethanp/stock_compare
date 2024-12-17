import 'package:flutter/material.dart';
import 'package:stock_compare/ui/pages/first_page.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stock Compare',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Stock Compare')),
        body: const SafeArea(child: FirstPage()),
      ),
    );
  }
}
