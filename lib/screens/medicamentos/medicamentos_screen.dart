import 'package:flutter/material.dart';

import '../../widgets/placeholder_view.dart';

class MedicamentosScreen extends StatelessWidget {
  const MedicamentosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meus remédios')),
      body: const PlaceholderView(
        icon: Icons.notifications_active,
        mensagem: 'Cadastro de remédios e lembretes — Sprint 1',
      ),
    );
  }
}
