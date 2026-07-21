import 'dart:math';

String generateUniqueId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final rand = Random.secure();
  final suffix = List.generate(
    10,
    (_) => chars[rand.nextInt(chars.length)],
  ).join();
  return 'split_$suffix';
}
