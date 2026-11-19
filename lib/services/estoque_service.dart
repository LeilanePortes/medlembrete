import '../models/medicamento.dart';
import 'medicamento_repository.dart';
import 'notification_service.dart';

/// O que aconteceu com o estoque depois de uma mudança.
class MudancaEstoque {
  const MudancaEstoque(this.antes, this.depois);

  final Medicamento antes;
  final Medicamento depois;

  /// true só na mudança que fez o estoque ficar baixo (cruzou o limite),
  /// para o aviso não se repetir a cada dose.
  bool get ficouBaixo => !antes.estoqueBaixo && depois.estoqueBaixo;

  /// O estoque passou de "tem" para "acabou" (ou o contrário): o texto
  /// das notificações de lembrete muda.
  bool get mudouAcabou => antes.estoqueAcabou != depois.estoqueAcabou;
}

/// Controle de estoque: desconta a cada dose comprovada, devolve quando o
/// comprovante é excluído, repõe quando o usuário compra mais e avisa com
/// uma notificação quando o remédio está acabando.
class EstoqueService {
  EstoqueService._();
  static final EstoqueService instance = EstoqueService._();

  /// Notificação "remédio acabando" (uma por remédio).
  static int idAviso(int medicamentoId) =>
      NotificationService.idNotificacao(medicamentoId, 198);

  /// Desconta uma dose. Retorna quantas unidades foram descontadas
  /// (null se o remédio não controla estoque).
  Future<int?> descontarDose(int medicamentoId) async {
    final m = MedicamentoRepository.instance.porId(medicamentoId);
    if (m == null || !m.controlaEstoque) return null;
    // Nunca fica negativo: desconta no máximo o que existe.
    final descontar =
        m.estoque! < m.unidadesPorDose ? m.estoque! : m.unidadesPorDose;
    await _aplicar(m, m.estoque! - descontar);
    return descontar;
  }

  /// Devolve unidades (comprovante excluído).
  Future<void> devolver(int medicamentoId, int unidades) async {
    final m = MedicamentoRepository.instance.porId(medicamentoId);
    if (m == null || !m.controlaEstoque || unidades <= 0) return;
    await _aplicar(m, m.estoque! + unidades);
  }

  /// Soma [unidades] compradas ao estoque.
  Future<MudancaEstoque?> repor(int medicamentoId, int unidades) async {
    final m = MedicamentoRepository.instance.porId(medicamentoId);
    if (m == null || unidades <= 0) return null;
    return _aplicar(m, (m.estoque ?? 0) + unidades);
  }

  Future<MudancaEstoque> _aplicar(Medicamento m, int novoEstoque) async {
    final mudanca = MudancaEstoque(m, m.comEstoque(novoEstoque));
    await MedicamentoRepository.instance.salvar(mudanca.depois);
    await reagir(mudanca);
    return mudanca;
  }

  /// Avisa quando o estoque fica baixo e atualiza o texto dos lembretes
  /// quando ele acaba ou volta. Também usado pelo formulário ao salvar.
  Future<void> reagir(MudancaEstoque mudanca) async {
    final m = mudanca.depois;
    final notificacoes = NotificationService.instance;
    if (mudanca.ficouBaixo) {
      await notificacoes.mostrarAgora(
        id: idAviso(m.id),
        titulo: m.estoqueAcabou
            ? '📦 ${m.nome} acabou'
            : '📦 ${m.nome} está acabando',
        corpo: textoAviso(m),
        payload: '${NotificationService.prefixoEstoque}${m.id}',
      );
    }
    if (mudanca.mudouAcabou) await notificacoes.agendarLembretes(m);
  }

  /// "Restam 3 comprimidos (≈ 1 dia). Lembre de comprar mais."
  static String textoAviso(Medicamento m, [DateTime? agora]) {
    if (m.estoqueAcabou) {
      return 'Seu estoque acabou. Compre mais e toque em "Repor" no app.';
    }
    final dias = m.diasDeEstoque(agora) ?? 0;
    return 'Restam ${m.descreverQuantidade(m.estoque!)} '
        '(≈ $dias ${dias == 1 ? 'dia' : 'dias'}). Lembre de comprar mais.';
  }
}
