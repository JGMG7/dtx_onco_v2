class ResumenParticipante {
  final String idParticipante;
  final String? grupo;
  final String cohorte;
  final DateTime? ultimoRegistro;
  final int? diasSinRegistro;
  final bool registroHoy;

  const ResumenParticipante({
    required this.idParticipante,
    this.grupo,
    required this.cohorte,
    required this.ultimoRegistro,
    required this.diasSinRegistro,
    required this.registroHoy,
  });
}
