// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/src/analysis_options/error/option_codes.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'analysis_options_test_support.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(IncludeFileNotFoundTest);
  });
}

@reflectiveTest
class IncludeFileNotFoundTest extends AbstractAnalysisOptionsTest {
  void test_notFound_existent_doubleQuoted() {
    assertErrorsInCode(
      '''
include: "./analysis_options.yaml"
''',
      [error(AnalysisOptionsWarningCode.RECURSIVE_INCLUDE_FILE, 9, 25)],
    );
  }

  void test_notFound_existent_notQuoted() {
    assertErrorsInCode(
      '''
include: ./analysis_options.yaml
''',
      [error(AnalysisOptionsWarningCode.RECURSIVE_INCLUDE_FILE, 9, 23)],
    );
  }

  void test_notFound_existent_singleQuoted() {
    assertErrorsInCode(
      '''
include: './analysis_options.yaml'
''',
      [error(AnalysisOptionsWarningCode.RECURSIVE_INCLUDE_FILE, 9, 25)],
    );
  }

  void test_notFound_nonexistent_doubleQuoted() {
    assertErrorsInCode(
      '''
# We don't depend on pedantic, but we should consider adding it.
include: "package:pedantic/analysis_options.yaml"
''',
      [
        error(
          AnalysisOptionsWarningCode.INCLUDE_FILE_NOT_FOUND,
          74,
          40,
          text:
              "The include file 'package:pedantic/analysis_options.yaml'"
              " in '${convertPath('/analysis_options.yaml')}' can't be found when analyzing '/'.",
        ),
      ],
    );
  }

  void test_notFound_nonexistent_notQuoted() {
    assertErrorsInCode(
      '''
# We don't depend on pedantic, but we should consider adding it.
include: package:pedantic/analysis_options.yaml
''',
      [
        error(
          AnalysisOptionsWarningCode.INCLUDE_FILE_NOT_FOUND,
          74,
          38,
          text:
              "The include file 'package:pedantic/analysis_options.yaml'"
              " in '${convertPath('/analysis_options.yaml')}' can't be found when analyzing '/'.",
        ),
      ],
    );
  }

  void test_notFound_nonexistent_singleQuoted() {
    assertErrorsInCode(
      '''
# We don't depend on pedantic, but we should consider adding it.
include: 'package:pedantic/analysis_options.yaml'
''',
      [
        error(
          AnalysisOptionsWarningCode.INCLUDE_FILE_NOT_FOUND,
          74,
          40,
          text:
              "The include file 'package:pedantic/analysis_options.yaml'"
              " in '${convertPath('/analysis_options.yaml')}' can't be found when analyzing '/'.",
        ),
      ],
    );
  }
}
