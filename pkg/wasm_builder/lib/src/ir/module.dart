// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

import '../serialize/serialize.dart';
import 'ir.dart';

/// A logically const wasm module ready to encode. Created with `ModuleBuilder`.
class Module implements Serializable {
  final String moduleName;
  final Functions functions;
  final Tables tables;
  final Tags tags;
  final Memories memories;
  final Exports exports;
  final Globals globals;
  final Types types;
  final DataSegments dataSegments;
  final List<Import> imports;
  final List<int> watchPoints;
  final Uri? sourceMapUrl;

  Module(
      this.moduleName,
      this.sourceMapUrl,
      this.functions,
      this.tables,
      this.tags,
      this.memories,
      this.exports,
      this.globals,
      this.types,
      this.dataSegments,
      this.imports,
      this.watchPoints);

  /// Serialize a module to its binary representation.
  @override
  void serialize(Serializer s) {
    if (watchPoints.isNotEmpty) {
      Serializer.traceEnabled = true;
    }
    // Wasm module preamble: magic number, version 1.
    s.writeBytes(Uint8List.fromList(
        const [0x00, 0x61, 0x73, 0x6D, 0x01, 0x00, 0x00, 0x00]));
    TypeSection(types, watchPoints).serialize(s);
    ImportSection(imports, watchPoints).serialize(s);
    FunctionSection(functions.defined, watchPoints).serialize(s);
    TableSection(tables.defined, watchPoints).serialize(s);
    MemorySection(memories.defined, watchPoints).serialize(s);
    TagSection(tags.defined, watchPoints).serialize(s);
    GlobalSection(globals.defined, watchPoints).serialize(s);
    ExportSection(exports.exported, watchPoints).serialize(s);
    StartSection(functions.start, watchPoints).serialize(s);
    ElementSection(
            tables.defined, tables.imported, functions.declared, watchPoints)
        .serialize(s);
    DataCountSection(dataSegments.defined, watchPoints).serialize(s);
    CodeSection(functions.defined, watchPoints).serialize(s);
    DataSection(dataSegments.defined, watchPoints).serialize(s);
    if (sourceMapUrl != null) {
      SourceMapSection(sourceMapUrl.toString()).serialize(s);
    }

    if (functions.namedCount > 0 ||
        types.namedCount > 0 ||
        globals.namedCount > 0) {
      NameSection(
              moduleName,
              <BaseFunction>[...functions.imported, ...functions.defined],
              types.recursionGroups,
              <Global>[...globals.imported, ...globals.defined],
              watchPoints,
              functionNameCount: functions.namedCount,
              typeNameCount: types.namedCount,
              globalNameCount: globals.namedCount,
              typesWithNamedFieldsCount: types.typesWithNamedFieldsCount)
          .serialize(s);
    }
  }
}
