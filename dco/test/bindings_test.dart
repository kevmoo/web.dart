import 'package:test/test.dart';
import '../example/example.dart';

void main() {
  test('add and greet component works via generated bindings', () async {
    const modulePath =
        '/Users/kevmoo/github/web/dco/example/jco_output/_wasm_rust_example.js';

    print('Loading Add module...');
    final adder = await Add.load(modulePath);
    print('Add module loaded.');

    print('Testing add...');
    final addResult = adder.add(10, 20);
    expect(addResult, equals(30));

    print('Testing greet...');
    final greetResult = adder.greet('Alice');
    expect(greetResult, equals('Hello, Alice!'));
  });
}
