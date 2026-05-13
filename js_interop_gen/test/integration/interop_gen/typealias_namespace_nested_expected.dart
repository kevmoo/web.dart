// ignore_for_file: camel_case_types, constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars, non_constant_identifier_names
// ignore_for_file: unintended_html_in_doc_comment, unnecessary_parenthesis

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:js_interop' as _i1;

import 'package:meta/meta.dart' as _i2;

extension type symlink._(_i1.JSObject _) implements _i1.JSObject {}
@_i1.JS()
external void mySymlink(symlink_Type type);
extension type stream._(_i1.JSObject _) implements _i1.JSObject {
  @_i1.JS('stream.Readable')
  static stream_Readable Readable() => stream_Readable();
}
@_i1.JS('stream.Readable')
extension type stream_Readable._(_i1.JSObject _) implements _i1.JSObject {
  external stream_Readable();
}
extension type MyReadable._(_i1.JSObject _) implements stream_Readable {
  external MyReadable();
}
extension type Empty._(_i1.JSObject _) implements _i1.JSObject {}
@_i2.doNotStore
@_i1.JS()
external _i1.JSAny? get emptyKey;
typedef symlink_Type = Type;
extension type const Type._(String _) {
  static const Type dir = Type._('dir');

  static const Type file = Type._('file');
}
