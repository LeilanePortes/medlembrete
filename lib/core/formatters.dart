/// Funções simples de formatação de data/hora (pt-BR) sem dependências.
String _doisDigitos(int n) => n.toString().padLeft(2, '0');

/// "08:05"
String formatarHora(DateTime d) => '${_doisDigitos(d.hour)}:${_doisDigitos(d.minute)}';

/// "18/11/2026"
String formatarData(DateTime d) =>
    '${_doisDigitos(d.day)}/${_doisDigitos(d.month)}/${d.year}';

/// "18/11/2026 às 08:05"
String formatarDataHora(DateTime d) => '${formatarData(d)} às ${formatarHora(d)}';

bool mesmoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
