import 'package:flutter_test/flutter_test.dart';
import 'package:dtx_onco_v2/logic/motor_clinico.dart';

void main() {
  group('calcularSemanaPrograma', () {
    test('el día de inicio es semana 1', () {
      final inicio = DateTime(2026, 1, 5); // lunes
      expect(MotorClinico.calcularSemanaPrograma(inicio, inicio), 1);
    });

    test('día 6 (última semana 1) sigue siendo semana 1', () {
      final inicio = DateTime(2026, 1, 5);
      expect(MotorClinico.calcularSemanaPrograma(inicio, inicio.add(const Duration(days: 6))), 1);
    });

    test('día 7 pasa a semana 2', () {
      final inicio = DateTime(2026, 1, 5);
      expect(MotorClinico.calcularSemanaPrograma(inicio, inicio.add(const Duration(days: 7))), 2);
    });

    test('semana 12 exacta (día 77-83)', () {
      final inicio = DateTime(2026, 1, 5);
      expect(MotorClinico.calcularSemanaPrograma(inicio, inicio.add(const Duration(days: 77))), 12);
      expect(MotorClinico.calcularSemanaPrograma(inicio, inicio.add(const Duration(days: 83))), 12);
    });

    test('semana 13 en adelante (fuera del programa de 12 semanas)', () {
      final inicio = DateTime(2026, 1, 5);
      expect(MotorClinico.calcularSemanaPrograma(inicio, inicio.add(const Duration(days: 84))), 13);
    });

    test('nunca devuelve menos de 1 aunque la fecha de referencia sea anterior al inicio', () {
      final inicio = DateTime(2026, 1, 5);
      expect(MotorClinico.calcularSemanaPrograma(inicio, inicio.subtract(const Duration(days: 3))), 1);
    });
  });

  group('esSemanaDescarga', () {
    test('semanas 4, 8 y 12 son descarga', () {
      expect(MotorClinico.esSemanaDescarga(4), isTrue);
      expect(MotorClinico.esSemanaDescarga(8), isTrue);
      expect(MotorClinico.esSemanaDescarga(12), isTrue);
    });

    test('el resto de semanas 1-12 no son descarga', () {
      for (final semana in [1, 2, 3, 5, 6, 7, 9, 10, 11]) {
        expect(MotorClinico.esSemanaDescarga(semana), isFalse, reason: 'semana $semana no debería ser descarga');
      }
    });

    test('más allá de la semana 12 (mantenimiento) nunca es descarga', () {
      expect(MotorClinico.esSemanaDescarga(13), isFalse);
      expect(MotorClinico.esSemanaDescarga(16), isFalse);
    });
  });

  group('esFaseExploracion', () {
    test('semanas 1 y 2 son exploración', () {
      expect(MotorClinico.esFaseExploracion(1), isTrue);
      expect(MotorClinico.esFaseExploracion(2), isTrue);
    });

    test('semana 3 en adelante ya no es exploración', () {
      for (final semana in [3, 4, 8, 12, 15]) {
        expect(MotorClinico.esFaseExploracion(semana), isFalse, reason: 'semana $semana no debería ser exploración');
      }
    });
  });

  group('nombreBloque', () {
    test('semanas 1-4 son Bloque 1', () {
      for (final semana in [1, 2, 3, 4]) {
        expect(MotorClinico.nombreBloque(semana), contains('Bloque 1'));
      }
    });

    test('semanas 5-8 son Bloque 2', () {
      for (final semana in [5, 6, 7, 8]) {
        expect(MotorClinico.nombreBloque(semana), contains('Bloque 2'));
      }
    });

    test('semanas 9-12 son Bloque 3', () {
      for (final semana in [9, 10, 11, 12]) {
        expect(MotorClinico.nombreBloque(semana), contains('Bloque 3'));
      }
    });

    test('más allá de la semana 12 es Fase de Mantenimiento', () {
      expect(MotorClinico.nombreBloque(13), contains('Mantenimiento'));
    });
  });

  group('obtenerIntensidad', () {
    test('el RIR de miércoles baja progresivamente en cada bloque de 3 semanas', () {
      // Bloque 1: semana 1 (RIR5) -> semana 2 (RIR4) -> semana 3 (RIR3, pico)
      expect(MotorClinico.obtenerIntensidad(1, 3), contains('RIR 5'));
      expect(MotorClinico.obtenerIntensidad(2, 3), contains('RIR 4'));
      expect(MotorClinico.obtenerIntensidad(3, 3), contains('RIR 3'));
      // Semana 4: descarga, vuelve a RIR alto (más fácil)
      expect(MotorClinico.obtenerIntensidad(4, 3), contains('RIR 5'));
      expect(MotorClinico.obtenerIntensidad(4, 3), contains('Descarga'));
    });

    test('lunes es 1 punto de RIR más suave que miércoles en la misma semana', () {
      expect(MotorClinico.obtenerIntensidad(3, 1), contains('RIR 4')); // miércoles semana 3 = RIR3, lunes = RIR4
    });

    test('viernes es 2 puntos de RIR más suave que miércoles en la misma semana', () {
      expect(MotorClinico.obtenerIntensidad(3, 5), contains('RIR 5')); // miércoles semana 3 = RIR3, viernes = RIR5
    });

    test('el pico del programa (semana 11) es RIR 2 el miércoles', () {
      expect(MotorClinico.obtenerIntensidad(11, 3), contains('RIR 2'));
    });

    test('mantenimiento (semana >12) usa RIR moderado fijo', () {
      expect(MotorClinico.obtenerIntensidad(15, 3), contains('Mantenimiento'));
      expect(MotorClinico.obtenerIntensidad(15, 3), contains('RIR 3'));
    });

    test('día distinto de L/M/V devuelve el mensaje de recuperación pasiva', () {
      expect(MotorClinico.obtenerIntensidad(3, 2), 'Monitoreo Pasivo / Recuperación');
    });
  });

  group('obtenerRutina', () {
    test('siempre devuelve exactamente 4 ejercicios para días de entrenamiento', () {
      for (final cohorte in ['MAMA', 'PROSTATA']) {
        for (final dia in [1, 3, 5]) {
          expect(MotorClinico.obtenerRutina(cohorte, dia).length, 4,
              reason: '$cohorte día $dia debería tener 4 ejercicios');
        }
      }
    });

    test('un día que no es L/M/V devuelve "Descanso"', () {
      final rutina = MotorClinico.obtenerRutina('MAMA', 2);
      expect(rutina.every((e) => e.nombre == 'Descanso'), isTrue);
    });

    test('MAMA y PROSTATA tienen rutinas distintas el mismo día', () {
      final mama = MotorClinico.obtenerRutina('MAMA', 1).map((e) => e.nombre).toList();
      final prostata = MotorClinico.obtenerRutina('PROSTATA', 1).map((e) => e.nombre).toList();
      expect(mama, isNot(equals(prostata)));
    });

    test('la cohorte no distingue mayúsculas/minúsculas', () {
      final a = MotorClinico.obtenerRutina('MAMA', 1).map((e) => e.nombre).toList();
      final b = MotorClinico.obtenerRutina('mama', 1).map((e) => e.nombre).toList();
      expect(a, equals(b));
    });

    test('ningún ejercicio prescrito requiere máquinas/polea/barra/TRX (kit real del piloto)', () {
      final terminosNoDisponibles = ['máquina', 'polea', 'trx', 'hexagonal', 'barra'];
      for (final cohorte in ['MAMA', 'PROSTATA']) {
        for (final dia in [1, 3, 5]) {
          for (final ejercicio in MotorClinico.obtenerRutina(cohorte, dia)) {
            final nombreLower = ejercicio.nombre.toLowerCase();
            for (final termino in terminosNoDisponibles) {
              expect(nombreLower.contains(termino), isFalse,
                  reason: '"${ejercicio.nombre}" ($cohorte, día $dia) menciona "$termino", no disponible en el kit');
            }
          }
        }
      }
    });

    test('los ejercicios de tipo banda tienen "Banda" en el nombre (consistencia)', () {
      for (final cohorte in ['MAMA', 'PROSTATA']) {
        for (final dia in [1, 3, 5]) {
          for (final ejercicio in MotorClinico.obtenerRutina(cohorte, dia)) {
            if (ejercicio.tipoCarga == TipoCarga.banda) {
              expect(ejercicio.nombre.toLowerCase(), contains('banda'));
            }
          }
        }
      }
    });
  });
}
