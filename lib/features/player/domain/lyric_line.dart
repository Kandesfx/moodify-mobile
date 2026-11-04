class LyricLine {
  const LyricLine(this.at, this.text);
  final Duration at;
  final String text;
}

List<LyricLine> parseLrc(String? source) {
  if (source == null) return [];
  final lines = <LyricLine>[];
  final timestamp = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');
  final offset =
      int.tryParse(
        RegExp(r'\[offset:([+-]?\d+)\]').firstMatch(source)?.group(1) ?? '',
      ) ??
      0;
  for (final line in source.split('\n').take(2000)) {
    final matches = timestamp.allMatches(line).toList();
    if (matches.isEmpty) continue;
    final text = line.substring(matches.last.end).trim();
    if (text.isEmpty) continue;
    for (final match in matches) {
      final seconds = int.parse(match[2]!);
      if (seconds >= 60) continue;
      final fraction = (match[3] ?? '').padRight(3, '0');
      final ms =
          int.parse(match[1]!) * 60000 +
          seconds * 1000 +
          int.parse(fraction) +
          offset;
      lines.add(LyricLine(Duration(milliseconds: ms < 0 ? 0 : ms), text));
    }
  }
  lines.sort((a, b) => a.at.compareTo(b.at));
  return List.unmodifiable(lines);
}
