import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  test('generates 10000 collision-free UUIDv4 expense ids', () {
    const uuid = Uuid();
    final ids = <String>{};
    final uuidV4Pattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    for (var i = 0; i < 10000; i++) {
      final id = uuid.v4();
      expect(uuidV4Pattern.hasMatch(id), isTrue);
      expect(ids.add(id), isTrue);
    }
  });
}
