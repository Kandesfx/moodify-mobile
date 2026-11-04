import 'package:intl/intl.dart';

String displayDate(String? value) {
  if (value == null || value.isEmpty) return 'Chưa xác định';
  final date = DateTime.tryParse(value.replaceFirst(' ', 'T'));
  if (date == null) return value;
  // Preserve the server's wall time when its response has no timezone.
  return DateFormat('dd/MM/yyyy HH:mm').format(date);
}
