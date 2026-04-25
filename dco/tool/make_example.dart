import 'dart:io';

void main() async {
  const rustProjectDir = '../_wasm_rust_example';
  const wasmFile =
      '$rustProjectDir/target/wasm32-wasip2/release/_wasm_rust_example.wasm';

  print('Step 1: Building Rust component...');
  final cargoResult = Process.runSync('cargo', [
    'build',
    '--target=wasm32-wasip2',
    '--release',
  ], workingDirectory: rustProjectDir);

  if (cargoResult.exitCode != 0) {
    print('Error: Failed to build Rust component.');
    print(cargoResult.stderr);
    exitCode = 1;
    return;
  }
  print('Rust component built successfully.');

  print('Step 2: Extracting WIT as JSON...');
  final wasmToolsResult = Process.runSync('wasm-tools', [
    'component',
    'wit',
    wasmFile,
    '--json',
  ]);

  if (wasmToolsResult.exitCode != 0) {
    print('Error: Failed to extract WIT.');
    print(wasmToolsResult.stderr);
    exitCode = 1;
    return;
  }

  final jsonFile = File('test_component.json');
  jsonFile.writeAsStringSync(wasmToolsResult.stdout as String);
  print('Extracted WIT to ${jsonFile.path}');

  print('Step 3: Generating bindings...');
  final genResult = Process.runSync('dart', ['run', 'dco:generate_bindings']);

  if (genResult.exitCode != 0) {
    print('Error: Failed to generate bindings.');
    print(genResult.stderr);
    exitCode = 1;
    return;
  }

  print('Bindings generated successfully in example/example.dart');
}
