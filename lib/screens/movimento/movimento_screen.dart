import 'package:flutter/material.dart';

import '../../widgets/placeholder_view.dart';

class MovimentoScreen extends StatelessWidget {
  const MovimentoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Movimento')),
      body: const PlaceholderView(
        icon: Icons.sensors,
        mensagem: 'Acelerômetro X, Y e Z em tempo real — Sprint 4',
      ),
    );
  }
}
