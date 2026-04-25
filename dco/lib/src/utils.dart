String capitalize(String input) {
  if (input.isEmpty) return '';
  return input[0].toUpperCase() + input.substring(1);
}

String kebabToCamelCase(String input) {
  final parts = input.split('-');
  if (parts.isEmpty) return '';
  final first = parts.first;
  final rest = parts.skip(1).map((p) {
    if (p.isEmpty) return '';
    return p[0].toUpperCase() + p.substring(1);
  });
  return first + rest.join();
}
