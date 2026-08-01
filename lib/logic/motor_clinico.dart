// Motor de prescripción de ejercicio EFADAP.
//
// Dos ejes de periodización combinados:
// - Semanal (macro): 3 mesociclos de 4 semanas con patrón 3:1 (3 semanas de
//   progresión + 1 de descarga) para permitir supercompensación.
// - Diario (micro): dentro de cada semana, miércoles es el día ancla/pesado;
//   lunes es más suave (RIR +1) y viernes es regenerativo (RIR +2).
//
// El semáforo clínico (rojo/amarillo) siempre tiene prioridad sobre este plan
// base y se aplica por fuera, en PrescripcionScreen.

enum TipoCarga { peso, banda, corporal }

class Ejercicio {
  final String nombre;
  final TipoCarga tipoCarga;
  const Ejercicio(this.nombre, this.tipoCarga);
}

class MotorClinico {
  static List<Ejercicio> obtenerRutina(String cohorte, int diaSemana) {
    if (cohorte.toUpperCase() == "MAMA") {
      if (diaSemana == 1) {
        return const [
          Ejercicio("Sentadilla Copa con Mancuerna/Pesa Rusa", TipoCarga.peso),
          Ejercicio("Remo a 1 Brazo Apoyado en Banco", TipoCarga.peso),
          Ejercicio("Puente de Glúteos", TipoCarga.corporal),
          Ejercicio("Plancha Frontal", TipoCarga.corporal),
        ];
      }
      if (diaSemana == 3) {
        return const [
          Ejercicio("Sentadilla al Banco (Sit-to-Stand con Mancuernas)", TipoCarga.peso),
          Ejercicio("Press de Pecho con Mancuernas en el Suelo", TipoCarga.peso),
          Ejercicio("Peso Muerto Rumano con Mancuernas/Pesa Rusa", TipoCarga.peso),
          Ejercicio("Pallof Press con Banda", TipoCarga.banda),
        ];
      }
      if (diaSemana == 5) {
        return const [
          Ejercicio("Zancadas / Estocadas", TipoCarga.corporal),
          Ejercicio("Jalón al Pecho con Banda", TipoCarga.banda),
          Ejercicio("Extensión de Cadera (Patada de Glúteo)", TipoCarga.corporal),
          Ejercicio("Bird-Dog", TipoCarga.corporal),
        ];
      }
    } else {
      if (diaSemana == 1) {
        return const [
          Ejercicio("Sentadilla al Banco (Sit-to-Stand)", TipoCarga.corporal),
          Ejercicio("Press de Pecho con Mancuernas en Banco", TipoCarga.peso),
          Ejercicio("Remo Sentado con Banda", TipoCarga.banda),
          Ejercicio("Elevación de Talones", TipoCarga.corporal),
        ];
      }
      if (diaSemana == 3) {
        return const [
          Ejercicio("Peso Muerto Rumano con Pesas Rusas", TipoCarga.peso),
          Ejercicio("Press Militar con Mancuernas Sentado en Banco", TipoCarga.peso),
          Ejercicio("Jalón al Pecho con Banda", TipoCarga.banda),
          Ejercicio("Caminata del Granjero con Pesas Rusas", TipoCarga.peso),
        ];
      }
      if (diaSemana == 5) {
        return const [
          Ejercicio("Sentadilla Búlgara (pie trasero en banco)", TipoCarga.corporal),
          Ejercicio("Flexiones Inclinadas en Banco", TipoCarga.corporal),
          Ejercicio("Remo a 1 Brazo Apoyado en Banco", TipoCarga.peso),
          Ejercicio("Suelo Pélvico + Respiración Diafragmática (Kegel)", TipoCarga.corporal),
        ];
      }
    }
    return const [
      Ejercicio("Descanso", TipoCarga.corporal),
      Ejercicio("Descanso", TipoCarga.corporal),
      Ejercicio("Descanso", TipoCarga.corporal),
      Ejercicio("Descanso", TipoCarga.corporal),
    ];
  }

  // RIR del día ancla (miércoles) por semana del programa, semanas 1-12.
  // Semanas 4, 8 y 12 son descarga (fin de cada mesociclo de 4 semanas).
  static const Map<int, int> _rirMiercolesPorSemana = {
    1: 5, 2: 4, 3: 3, 4: 5,
    5: 4, 6: 3, 7: 2, 8: 5,
    9: 3, 10: 2, 11: 2, 12: 5,
  };

  static const int _rirMantenimiento = 3;

  static int calcularSemanaPrograma(DateTime fechaInicio, DateTime fechaReferencia) {
    final dias = fechaReferencia.difference(fechaInicio).inDays;
    final semana = (dias / 7).floor() + 1;
    return semana < 1 ? 1 : semana;
  }

  static bool esSemanaDescarga(int semanaPrograma) {
    if (semanaPrograma > 12) return false;
    return semanaPrograma % 4 == 0;
  }

  // Semanas 1-2: fase de exploración. Todavía no hay historial de cargas
  // fiable para el participante, así que el objetivo de la sesión es encontrar
  // la carga de referencia (ramp-up intrasesión), no aplicarla.
  static bool esFaseExploracion(int semanaPrograma) => semanaPrograma <= 2;

  static String nombreBloque(int semanaPrograma) {
    if (semanaPrograma > 12) return "Fase de Mantenimiento";
    if (semanaPrograma <= 4) return "Bloque 1: Adaptación Anatómica";
    if (semanaPrograma <= 8) return "Bloque 2: Progresión de Fuerza";
    return "Bloque 3: Consolidación";
  }

  static int _rirMiercoles(int semanaPrograma) {
    if (semanaPrograma > 12) return _rirMantenimiento;
    return _rirMiercolesPorSemana[semanaPrograma] ?? _rirMantenimiento;
  }

  static String obtenerIntensidad(int semanaPrograma, int diaSemana) {
    final int semanaMostrada = semanaPrograma > 12 ? 12 : semanaPrograma;
    final int rirBase = _rirMiercoles(semanaPrograma);
    final bool descarga = esSemanaDescarga(semanaPrograma);
    final String bloque = nombreBloque(semanaPrograma);

    int rirDia;
    String etiquetaDia;
    if (diaSemana == 1) {
      rirDia = rirBase + 1;
      etiquetaDia = "LUNES - Carga Base";
    } else if (diaSemana == 3) {
      rirDia = rirBase;
      etiquetaDia = "MIÉRCOLES - Día Pesado";
    } else if (diaSemana == 5) {
      rirDia = rirBase + 2;
      etiquetaDia = "VIERNES - Día Regenerativo";
    } else {
      return "Monitoreo Pasivo / Recuperación";
    }

    final String prefijoSemana = semanaPrograma > 12
        ? "Mantenimiento"
        : "Semana $semanaMostrada/12";
    final String sufijoDescarga = descarga ? " · Semana de Descarga" : "";

    return "$prefijoSemana · $bloque$sufijoDescarga · $etiquetaDia (RIR $rirDia)";
  }
}
