// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'server_abstract.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AnalysisStandardProgressTest);
    defineReflectiveTests(AnalyzerCustomStatusTest);
  });
}

/// Tests analysis status notifications using LSP-standard $/progress
/// notifications.
@reflectiveTest
class AnalysisStandardProgressTest extends AnalyzerStatusTest {
  @override
  bool get progressSupport => true;
}

/// Tests analysis status notifications using (legacy) custom notifications.
@reflectiveTest
class AnalyzerCustomStatusTest extends AnalyzerStatusTest {
  @override
  bool get progressSupport => false;
}

abstract class AnalyzerStatusTest extends AbstractLspAnalysisServerTest {
  bool get progressSupport;

  @override
  void setUp() {
    super.setUp();

    if (progressSupport) {
      setWorkDoneProgressSupport();
    }
  }

  Future<void> test_afterDocumentEdits() async {
    const initialContents = 'int a = 1;';
    newFile(mainFilePath, initialContents);

    await initialize();
    await initialAnalysis;

    // Set up futures to wait for the new events.
    var startNotification = waitForAnalysisStart();
    var completeNotification = waitForAnalysisComplete();

    // Send a modification
    await openFile(mainFileUri, initialContents);
    await replaceFile(222, mainFileUri, 'int a = 2;');

    // Ensure the notifications come through again.
    await startNotification;
    await completeNotification;
  }

  Future<void> test_afterInitialize() async {
    const initialContents = 'int a = 1;';
    newFile(mainFilePath, initialContents);

    // To avoid races, set up listeners for the notifications before we initialise
    // and track which event came first to ensure they arrived in the expected
    // order.
    bool? firstNotificationWasAnalyzing;
    var startNotification = waitForAnalysisStart().then(
      (_) => firstNotificationWasAnalyzing ??= true,
    );
    var completeNotification = waitForAnalysisComplete().then(
      (_) => firstNotificationWasAnalyzing ??= false,
    );

    await initialize();
    await startNotification;
    await completeNotification;

    expect(firstNotificationWasAnalyzing, isTrue);
  }
}
