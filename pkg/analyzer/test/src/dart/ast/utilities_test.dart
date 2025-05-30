// Copyright (c) 2014, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/src/dart/ast/utilities.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../../../generated/parser_test_base.dart' show ParserTestCase;
import '../../../util/ast_type_matchers.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NodeLocator2Test);
  });
}

@reflectiveTest
class NodeLocator2Test extends _SharedNodeLocatorTests {
  @override
  AstNode? locate(CompilationUnit unit, int start, [int? end]) {
    var locator = NodeLocator2(start, end);
    var node = locator.searchWithin(unit)!;
    return node;
  }

  void test_onlyStartOffset() {
    String code = ' f() {} ';
    //             01234567
    CompilationUnit unit = parseCompilationUnit(code);
    var function = unit.declarations.single as FunctionDeclaration;
    var expression = function.functionExpression;
    var body = expression.body as BlockFunctionBody;
    expect(NodeLocator2(0).searchWithin(unit), same(unit));
    expect(NodeLocator2(1).searchWithin(unit), same(function));
    expect(NodeLocator2(2).searchWithin(unit), same(function));
    expect(NodeLocator2(3).searchWithin(unit), same(expression.parameters));
    expect(NodeLocator2(4).searchWithin(unit), same(expression));
    expect(NodeLocator2(5).searchWithin(unit), same(body.block));
    expect(NodeLocator2(6).searchWithin(unit), same(body.block));
    expect(NodeLocator2(7).searchWithin(unit), same(unit));
    expect(NodeLocator2(100).searchWithin(unit), isNull);
  }

  void test_startEndOffset() {
    String code = ' f() {} ';
    //             01234567
    CompilationUnit unit = parseCompilationUnit(code);
    var function = unit.declarations.single as FunctionDeclaration;
    expect(NodeLocator2(-1, 2).searchWithin(unit), isNull);
    expect(NodeLocator2(0, 2).searchWithin(unit), same(unit));
    expect(NodeLocator2(1, 2).searchWithin(unit), same(function));
    expect(NodeLocator2(1, 3).searchWithin(unit), same(function));
    expect(NodeLocator2(1, 4).searchWithin(unit), same(function));
    expect(NodeLocator2(5, 7).searchWithin(unit), same(unit));
    expect(NodeLocator2(5, 100).searchWithin(unit), isNull);
    expect(NodeLocator2(100, 200).searchWithin(unit), isNull);
  }
}

abstract class _SharedNodeLocatorTests extends ParserTestCase {
  AstNode? locate(CompilationUnit unit, int start, [int? end]);

  void test_searchWithin_class_afterName_beforeTypeParameters() {
    var source = r'''
class A<T> {}
''';
    var unit = parseCompilationUnit(source);
    var node = _assertLocate(unit, source.indexOf('<T> {}'));
    expect(node, isClassDeclaration);
  }

  void test_searchWithin_constructor_afterName_beforeParameters() {
    var source = r'''
class A {
  A() {}
}
''';
    var unit = parseCompilationUnit(source);
    // TODO(dantup): Update these tests to use markers.
    var node = _assertLocate(unit, source.indexOf('() {}'));
    expect(node, isConstructorDeclaration);
  }

  void test_searchWithin_function_afterName_beforeParameters() {
    var source = r'''
void f() {}
''';
    var unit = parseCompilationUnit(source);
    var node = _assertLocate(unit, source.indexOf('() {}'));
    expect(node, isFunctionDeclaration);
  }

  void test_searchWithin_function_afterName_beforeTypeParameters() {
    var source = r'''
void f<T>() {}
''';
    var unit = parseCompilationUnit(source);
    var node = _assertLocate(unit, source.indexOf('<T>() {}'));
    expect(node, isFunctionDeclaration);
  }

  void test_searchWithin_method_afterName_beforeParameters() {
    var source = r'''
class A {
  void m() {}
}
''';
    var unit = parseCompilationUnit(source);
    var node = _assertLocate(unit, source.indexOf('() {}'));
    expect(node, isMethodDeclaration);
  }

  void test_searchWithin_method_afterName_beforeTypeParameters() {
    var source = r'''
class A {
  void m<T>() {}
}
''';
    var unit = parseCompilationUnit(source);
    var node = _assertLocate(unit, source.indexOf('<T>() {}'));
    expect(node, isMethodDeclaration);
  }

  void test_searchWithin_namedConstructor_afterName_beforeParameters() {
    var source = r'''
class A {
  A.c() {}
}
''';
    var unit = parseCompilationUnit(source);
    var node = _assertLocate(unit, source.indexOf('() {}'));
    expect(node, isConstructorDeclaration);
  }

  void test_searchWithin_setter_afterName_beforeParameters() {
    var source = r'''
set s(int i) {}
''';
    var unit = parseCompilationUnit(source);
    var node = _assertLocate(unit, source.indexOf('(int i)'));
    expect(node, isFunctionDeclaration);
  }

  AstNode _assertLocate(CompilationUnit unit, int start, [int? end]) {
    end ??= start;
    var node = locate(unit, start, end)!;
    expect(node.offset <= start, isTrue, reason: "Node starts after range");
    expect(
      node.offset + node.length > end,
      isTrue,
      reason: "Node ends before range",
    );
    return node;
  }
}
