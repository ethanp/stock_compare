import 'package:flutter/material.dart';
import 'package:stock_compare/ui/pages/dto_search_page.dart';
import 'package:stock_compare/ui/pages/first_page.dart';
import 'package:stock_compare/ui/pages/raw_search_page.dart';

class BottomSelectionWidget extends StatefulWidget {
  const BottomSelectionWidget();

  @override
  State<BottomSelectionWidget> createState() => _BottomSelectionWidgetState();
}

class _BottomSelectionWidgetState extends State<BottomSelectionWidget> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yahoo Finance Example')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: PageView(
          physics: const NeverScrollableScrollPhysics(),
          controller: _pageController,
          onPageChanged: _onItemSelected,
          children: const [
            YahooFinanceServiceWidget(),
            DTOSearch(),
            RawSearch(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        onTap: _onItemSelected,
        currentIndex: _selectedIndex,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.storage),
            label: 'Service',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.format_list_numbered),
            label: 'DTO',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.raw_on),
            label: 'Raw',
          ),
        ],
      ),
    );
  }

  void _onItemSelected(int index) {
    setState(() {
      _pageController.animateToPage(index,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      _selectedIndex = index;
    });
    debugPrint(index.toString());
  }
}
