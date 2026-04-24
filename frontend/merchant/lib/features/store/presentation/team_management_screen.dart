import 'package:flutter/material.dart';

class TeamManagementScreen extends StatelessWidget {
  const TeamManagementScreen({required this.storeId, super.key});
  final String storeId;
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('TeamManagement')));
}
