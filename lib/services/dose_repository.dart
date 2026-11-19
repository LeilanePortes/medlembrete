import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/formatters.dart';
import '../models/dose.dart';
import 'camera_service.dart';

/// Histórico de doses comprovadas (mais recentes primeiro).
class DoseRepository extends ChangeNotifier {
  DoseRepository._();
  static final DoseRepository instance = DoseRepository._();

  static const _chave = 'doses';

  final List<Dose> _itens = [];

  List<Dose> get doses {
    final lista = [..._itens]..sort((a, b) => b.dataHora.compareTo(a.dataHora));
    return List.unmodifiable(lista);
  }

  Future<void> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final texto = prefs.getString(_chave);
    _itens.clear();
    if (texto != null) {
      final lista = jsonDecode(texto) as List<dynamic>;
      _itens.addAll(lista.map((e) => Dose.fromJson(e as Map<String, dynamic>)));
    }
    notifyListeners();
  }

  Future<void> _persistir() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _chave,
      jsonEncode(_itens.map((d) => d.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<void> registrar(Dose dose) async {
    _itens.add(dose);
    await _persistir();
  }

  /// Remove o registro e apaga a foto do armazenamento.
  Future<void> remover(Dose dose) async {
    _itens.removeWhere((d) => d.id == dose.id);
    await CameraService.instance.apagarComprovante(dose.fotoPath);
    await _persistir();
  }

  /// Última dose do remédio registrada hoje, se houver.
  Dose? tomadaHoje(int medicamentoId, [DateTime? agora]) {
    final hoje = agora ?? DateTime.now();
    for (final d in doses) {
      if (d.medicamentoId == medicamentoId && mesmoDia(d.dataHora, hoje)) {
        return d;
      }
    }
    return null;
  }
}
