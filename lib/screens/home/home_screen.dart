import 'package:flutter/material.dart';

import '../../core/app_constants.dart';
import '../../widgets/feature_card.dart';
import '../../widgets/proxima_dose_card.dart';
import '../../widgets/status_hoje_card.dart';
import '../dose/dose_screen.dart';

/// Tela inicial: apresenta o app e dá atalhos para cada funcionalidade.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onNavegar});

  /// Troca a aba da barra de navegação inferior.
  final ValueChanged<int> onNavegar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appName)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Icon(Icons.medication_liquid,
                    size: 48, color: scheme.onPrimaryContainer),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Olá! 👋',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppConstants.slogan,
                        style: TextStyle(color: scheme.onPrimaryContainer),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ProximaDoseCard(onTap: () => onNavegar(1)),
          const SizedBox(height: 12),
          const StatusHojeCard(),
          const SizedBox(height: 24),
          Text('Funcionalidades',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            // Altura fixa: com cards quadrados (altura = largura), telas
            // estreitas não tinham espaço para o texto ("BOTTOM OVERFLOWED").
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 168,
            ),
            children: [
              FeatureCard(
                icon: Icons.notifications_active,
                titulo: 'Lembretes',
                descricao: 'Notificação no horário do remédio',
                onTap: () => onNavegar(1),
              ),
              FeatureCard(
                icon: Icons.photo_camera,
                titulo: 'Comprovação',
                descricao: 'Foto da caixa ou do comprimido',
                cor: Colors.deepPurple,
                onTap: () => abrirComprovacao(context),
              ),
              FeatureCard(
                icon: Icons.location_on,
                titulo: 'Localização',
                descricao: 'Em casa ou fora no momento da dose',
                cor: Colors.orange,
                onTap: () => onNavegar(3),
              ),
              FeatureCard(
                icon: Icons.sensors,
                titulo: 'Movimento',
                descricao: 'Celular parado (esquecido) ou em uso',
                cor: Colors.blue,
                onTap: () => onNavegar(4),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
