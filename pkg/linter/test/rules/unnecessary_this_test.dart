// Copyright (c) 2023, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../rule_test_support.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(UnnecessaryNullChecksTest);
  });
}

@reflectiveTest
class UnnecessaryNullChecksTest extends LintRuleTest {
  @override
  String get lintRule => LintNames.unnecessary_this;

  test_closureInMethod() async {
    await assertDiagnostics(
      r'''
class A {
  void m1(List<int> list) {
    list.forEach((e) {
      this.m2(e);
    });
  }
  void m2(int x) {}
}
''',
      [lint(67, 4)],
    );
  }

  test_constructorBody_assignment() async {
    await assertDiagnostics(
      r'''
class A {
  num x = 0;
  A.named(num a) {
    this.x = a;
  }
}
''',
      [lint(46, 4)],
    );
  }

  test_constructorBody_methodCall() async {
    await assertDiagnostics(
      r'''
class A {
  A.named() {
    this.m();
  }

  void m() {}
}
''',
      [lint(28, 4)],
    );
  }

  test_constructorBody_shadowedParameters() async {
    await assertNoDiagnostics(r'''
class A {
  num x = 0;
  A(num x) {
    this.x = x;
  }
}
''');
  }

  test_constructorInitializer() async {
    await assertDiagnostics(
      r'''
class A {
  num x = 0;
  A.c1(num x)
      : this.x = x;
}
''',
      [lint(45, 4)],
    );
  }

  test_extension_getter() async {
    await assertNoDiagnostics(r'''
extension E on int? {
  int? get h => this?.hashCode;
}
''');
  }

  test_extension_method() async {
    await assertNoDiagnostics(r'''
extension E on int? {
  String? f() => this?.toString();
}
''');
  }

  test_extensionType_inConstructorInitializer() async {
    await assertDiagnostics(
      r'''
extension type E(int i) {
  E.e(int i) : this.i = i.hashCode;
}
''',
      [lint(41, 4)],
    );
  }

  test_extensionType_inMethod() async {
    await assertDiagnostics(
      r'''
extension type E(Object o) {
  String m()=> this.toString();
}
''',
      [lint(44, 4)],
    );
  }

  test_initializingFormalParameter() async {
    await assertNoDiagnostics(r'''
class A {
  num x = 0, y = 0;
  A.bar(this.x, this.y);
}
''');
  }

  test_localFunctionPresent() async {
    await assertNoDiagnostics(r'''
class A {
  void m1() {
    if (true) {
      // ignore: unused_element
      void m2() {}
      this.m2();
    }
  }
  void m2() {}
}
''');
  }

  test_localFunctionPresent_outOfScope() async {
    await assertDiagnostics(
      r'''
class A {
  void m1() {
    if (true) {
      // ignore: unused_element
      void m2() {}
    }
    this.m2();
  }
  void m2() {}
}
''',
      [lint(101, 4)],
    );
  }

  test_method_ofGenericClass_noShadow_fromSelf() async {
    await assertDiagnostics(
      r'''
class A<T> {
  T foo() => throw 0;

  void bar() {
    this.foo();
  }
}
''',
      [lint(55, 4)],
    );
  }

  test_method_ofGenericClass_noShadow_fromSuper() async {
    await assertDiagnostics(
      r'''
class A<T> {
  T foo() => throw 0;
}

class B extends A<int> {
  void bar() {
    this.foo();
  }
}
''',
      [lint(82, 4)],
    );
  }

  test_shadowInIfCaseClause() async {
    await assertNoDiagnostics(r'''
class A {
  int? value;

  void m(A a) {
    if (a case A(:var value) when value != this.value) {}
  }
}
''');
  }

  test_shadowInMethodBody() async {
    await assertNoDiagnostics(r'''
class C {
  int x = 0;

  void m(bool b) {
    var x = this.x;
    print(x);
  }
}
''');
  }

  test_shadowInObjectPattern() async {
    await assertNoDiagnostics(r'''
class C {
  Object? value;
  bool equals(Object other) => switch (other) {
        C(:var value) => this.value == value,
        _ => false,
      };
}
''');
  }

  /// https://github.com/dart-lang/linter/issues/4457
  test_shadowInSwitchPatternCase() async {
    await assertNoDiagnostics(r'''
class C {
  int x = 0;

  int m(bool b) {
    switch (b) {
      case true:
        var x = this.x;
        return x;
      case false:
        return 7;
    }
  }
}
''');
  }

  /// https://github.com/dart-lang/linter/issues/4457
  test_shadowInSwitchPatternCase2() async {
    await assertNoDiagnostics(r'''
class C {
  bool isEven = false;

  bool m(int p) {
    switch (p) {
      case int(:var isEven) when isEven:
        isEven = this.isEven;
        return isEven;
      default:
        return false;
    }
  }
}
''');
  }

  /// https://github.com/dart-lang/linter/issues/4457
  test_shadowInSwitchPatternCase3() async {
    await assertNoDiagnostics(r'''
class C {
  bool isEven = false;

  bool m(int p) {
    switch (p) {
      case int(:var isEven) when this.isEven:
        isEven = this.isEven;
        return isEven;
      default:
        return false;
    }
  }
}
''');
  }

  test_subclass_noShadowing() async {
    await assertDiagnostics(
      r'''
class C {
  int x = 0;
}
class D extends C {
  void f(int a) {
    this.x = a;
  }
}
''',
      [lint(67, 4)],
    );
  }

  test_subclass_shadowedTopLevelVariable() async {
    await assertNoDiagnostics(r'''
int x = 0;
class C {
  int x = 0;
}
class D extends C {
  void m(int a) {
    this.x = a;
  }
}
''');
  }

  test_subclass_topLevelFunctionPresent() async {
    await assertNoDiagnostics(r'''
void m1() {}
class C {
  void m1() {}
}
class D extends C {
  void m2() {
    this.m1();
  }
}
''');
  }
}
