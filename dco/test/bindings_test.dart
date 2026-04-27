import 'dart:js_interop';
import 'package:test/test.dart';
import '../example/example.dart';

@JS('eval')
external JSAny jsEval(String code);

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

  test('showPerson works via generated bindings', () async {
    const modulePath =
        '/Users/kevmoo/github/web/dco/example/jco_output/_wasm_rust_example.js';

    final adder = await Add.load(modulePath);

    final person = jsEval('({ name: "Bob", age: 42 })') as Person;
    final result = adder.showPerson(person);
    expect(result, equals('Bob is 42 years old'));
  });
}
