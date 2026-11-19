import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dose_agendada.dart';
import '../models/medicamento.dart';

/// Guarda a lista de remédios no armazenamento local (SharedPreferences)
/// e avisa as telas quando ela muda (ChangeNotifier).
class MedicamentoRepository extends ChangeNotifier {
  MedicamentoRepository._();
  static final MedicamentoRepository instance = MedicamentoRepository._();

  static const _chave = 'medicamentos';

  final List<Medicamento> _itens = [];

  /// Lista ordenada pelo horário do dia.
  List<Medicamento> get medicamentos {
    final lista = [..._itens];
    lista.sort((a, b) => (a.hora * 60 + a.minuto) - (b.hora * 60 + b.minuto));
    return List.unmodifiable(lista);
  }

  Future<void> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final texto = prefs.getString(_chave);
    _itens.clear();
    if (texto != null) {
      final lista = jsonDecode(texto) as List<dynamic>;
      _itens.addAll(
        lista.map((e) => Medicamento.fromJson(e as Map<String, dynamic>)),
      );
    }
    notifyListeners();
  }

  Future<void> _persistir() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _chave,
      jsonEncode(_itens.map((m) => m.toJson()).toList()),
    );
    notifyListeners();
  }

  Medicamento? porId(int id) {
    for (final m in _itens) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// Insere um remédio novo ou atualiza um existente (mesmo id).
  Future<void> salvar(Medicamento medicamento) async {
    final indice = _itens.indexWhere((m) => m.id == medicamento.id);
    if (indice >= 0) {
      _itens[indice] = medicamento;
    } else {
      _itens.add(medicamento);
    }
    await _persistir();
  }

  Future<void> remover(int id) async {
    _itens.removeWhere((m) => m.id == id);
    await _persistir();
  }

  /// Próxima dose (remédio + horário) entre os remédios ativos.
  DoseAgendada? proximaDose([DateTime? agora]) {
    DoseAgendada? proxima;
    for (final m in _itens.where((m) => m.ativo)) {
      final t = m.proximaOcorrencia(agora);
      if (t != null && (proxima == null || t.isBefore(proxima.horario))) {
        proxima = DoseAgendada(m, t);
      }
    }
    return proxima;
  }
}
