// Copyright (c) 2018, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/dart/element/extensions.dart' // ignore: implementation_imports
    show Element2Extension;

import '../analyzer.dart';
import '../util/scope.dart';

const _desc = r'Avoid types as parameter names.';

class AvoidTypesAsParameterNames extends LintRule {
  AvoidTypesAsParameterNames()
    : super(name: LintNames.avoid_types_as_parameter_names, description: _desc);

  @override
  LintCode get lintCode => LinterLintCode.avoid_types_as_parameter_names;

  @override
  void registerNodeProcessors(
    NodeLintRegistry registry,
    LinterContext context,
  ) {
    var visitor = _Visitor(this, context);
    registry.addFormalParameterList(this, visitor);
    registry.addCatchClause(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final LintRule rule;
  final LinterContext context;

  _Visitor(this.rule, this.context);

  @override
  void visitCatchClause(CatchClause node) {
    var parameter = node.exceptionParameter;
    if (parameter != null && _isTypeName(node, parameter.name)) {
      rule.reportLint(parameter, arguments: [parameter.name.lexeme]);
    }
  }

  @override
  void visitFormalParameterList(FormalParameterList node) {
    for (var parameter in node.parameters) {
      var declaredElement = parameter.declaredFragment?.element;
      var name = parameter.name;
      if (declaredElement != null &&
          declaredElement is! FieldFormalParameterElement &&
          declaredElement.hasImplicitType &&
          name != null &&
          _isTypeName(node, name)) {
        rule.reportAtToken(name, arguments: [name.lexeme]);
      }
    }
  }

  bool _isTypeName(AstNode scope, Token name) {
    var result = resolveNameInScope(
      name.lexeme,
      scope,
      shouldResolveSetter: false,
    );
    if (result.isRequestedName) {
      var element = result.element;
      return element is ClassElement ||
          element is ExtensionTypeElement ||
          element is TypeAliasElement ||
          (element is TypeParameterElement && !element.isWildcardVariable);
    }
    return false;
  }
}
