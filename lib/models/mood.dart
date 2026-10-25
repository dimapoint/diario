class Mood {
  const Mood._(this.value, this.emoji, this.label);

  final int value;
  final String emoji;
  final String label;

  static const all = [
    Mood._(1, '😞', 'Muy mal'),
    Mood._(2, '🙁', 'Mal'),
    Mood._(3, '😐', 'Normal'),
    Mood._(4, '🙂', 'Bien'),
    Mood._(5, '😄', 'Muy bien'),
  ];

  static Mood? of(int? value) =>
      (value == null || value < 1 || value > 5) ? null : all[value - 1];
}
