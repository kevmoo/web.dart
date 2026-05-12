// ignore_for_file: constant_identifier_names, lines_longer_than_80_chars
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: unintended_html_in_doc_comment, unnecessary_parenthesis

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:js_interop' as _i1;

extension type A._(_i1.JSObject _) implements _i1.JSObject {
  external A();
}
extension type B._(_i1.JSObject _) implements _i1.JSObject {
  external B();
}
@_i1.JS()
external UnionType get unionVal;
@_i1.JS()
external HyphenatedEnum get hyphenatedVal;
extension type UnionType._(_i1.JSObject _) implements _i1.JSObject {
  A get asA => (_ as A);

  B get asB => (_ as B);
}
extension type const HyphenatedEnum._(String _) {
  static const HyphenatedEnum utf_8 = HyphenatedEnum._('utf-8');

  static const HyphenatedEnum utf_16le = HyphenatedEnum._('utf-16le');

  static const HyphenatedEnum ucs_2 = HyphenatedEnum._('ucs-2');
}
