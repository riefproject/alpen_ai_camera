class DateTimeFormatter {
  const DateTimeFormatter();

  // TODO: Format timestamps from camera events into UI-friendly and log-friendly text.
  String format(DateTime value) {
    String twoDigits(int input) => input.toString().padLeft(2, '0');

    return '${value.year}-${twoDigits(value.month)}-${twoDigits(value.day)} '
        '${twoDigits(value.hour)}:${twoDigits(value.minute)}:'
        '${twoDigits(value.second)}';
  }
}
