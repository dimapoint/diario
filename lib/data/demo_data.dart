import '../models/activity.dart';
import '../models/day_id.dart';
import '../models/entry.dart';
import '../models/song.dart';

/// Entradas de ejemplo para el modo demo, relativas a hoy.
List<DiaryEntry> demoEntries() {
  final now = today();
  String day(int daysAgo) => dayIdOf(DateTime(now.year, now.month, now.day - daysAgo));
  var n = 0;
  List<Activity> acts(List<String> texts) => [for (final t in texts) Activity(id: 'demo-${n++}', text: t)];

  return [
    DiaryEntry(
      id: day(1),
      mood: 4,
      highlight: 'Por fin terminé el informe y salí a caminar al atardecer',
      freeText: 'Arranqué el día lento, pero después del almuerzo me enganché y terminé el informe que '
          'venía pateando hace semanas. A la tarde salí a caminar por el parque y el cielo estaba '
          'naranja. Me quedé pensando en lo bien que me hace salir aunque sea media hora.',
      activities: acts(['Trabajo', 'Caminata', 'Cociné guiso']),
      tags: const ['trabajo', 'aire libre'],
      songOfDay: const Song(title: 'Ojos así', artist: 'Shakira'),
      listened: const [Song(title: 'Charly García'), Song(title: 'Clics modernos', artist: 'Charly García')],
    ),
    DiaryEntry(
      id: day(2),
      mood: 3,
      freeText: 'Día tranquilo. Leí bastante y ordené un poco la casa.',
      activities: acts(['Leí', 'Limpieza']),
      tags: const ['casa'],
    ),
    DiaryEntry(
      id: day(3),
      mood: 5,
      highlight: 'Asado con amigos que no veía hace meses',
      activities: [
        ...acts(['Asado', 'Fútbol']),
        Activity(
          id: 'demo-lb',
          text: 'Perfect Days (2023)',
          kind: ActivityKind.movie,
          source: 'letterboxd',
          externalId: 'https://boxd.it/demo',
          rating: 4.5,
        ),
      ],
      tags: const ['amigos'],
      songOfDay: const Song(title: 'Mil horas', artist: 'Los Abuelos de la Nada'),
    ),
    DiaryEntry(
      id: day(5),
      mood: 2,
      highlight: 'Me dolió la cabeza todo el día',
      activities: acts(['Trabajo']),
      tags: const ['trabajo'],
    ),
    DiaryEntry(
      id: day(6),
      mood: 4,
      freeText: 'Probé una receta nueva de pan. Salió medio denso pero rico. La próxima dejo levar más.',
      activities: acts(['Cociné pan', 'Gym']),
      tags: const ['cocina', 'casa'],
      listened: const [Song(title: 'Spinetta')],
    ),
    DiaryEntry(
      id: day(9),
      mood: 3,
      activities: acts(['Trabajo', 'Gym']),
      tags: const ['trabajo'],
      songOfDay: const Song(title: 'Seminare', artist: 'Serú Girán'),
    ),
    DiaryEntry(
      id: day(12),
      mood: 5,
      highlight: 'Viaje a la costa',
      freeText: 'Salimos temprano a la ruta. El mar estaba frío pero igual nos metimos.',
      activities: acts(['Viaje', 'Playa']),
      tags: const ['viaje', 'familia'],
    ),
    DiaryEntry(
      id: day(33),
      mood: 4,
      highlight: 'Cumpleaños de mamá',
      activities: acts(['Familia']),
      tags: const ['familia'],
    ),
  ];
}
