import 'package:flutter/material.dart';

import '../../widgets/placeholder_view.dart';

class LocalizacaoScreen extends StatelessWidget {
  const LocalizacaoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Localização')),
      body: const PlaceholderView(
        icon: Icons.location_on,
        mensagem: 'Latitude, longitude e "em casa ou fora" — Sprint 3',
      ),
    );
  }
}
