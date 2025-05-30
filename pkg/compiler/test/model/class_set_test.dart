// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Test for iterators on for [SubclassNode].

library class_set_test;

import 'package:expect/async_helper.dart';
import 'package:expect/expect.dart';
import 'package:compiler/src/elements/entities.dart' show ClassEntity;
import 'package:compiler/src/kernel/kernel_world.dart';
import 'package:compiler/src/universe/class_set.dart';
import 'package:compiler/src/util/enumset.dart';
import 'package:compiler/src/js_model/js_world.dart' show JClosedWorld;
import '../helpers/type_test_helper.dart';

void main() {
  asyncTest(() async {
    await testAll();
  });
}

testAll() async {
  await testIterators();
  await testForEach();
  await testClosures();
}

testIterators() async {
  var env = await TypeEnvironment.create(r"""
      ///        A
      ///       / \
      ///      B   C
      ///     /   /|\
      ///    D   E F G
      ///
      class A {}
      class B extends A {}
      class C extends A {}
      class D extends B {}
      class E extends C {}
      class F extends C {}
      class G extends C {}

      main() {
        A();
        C();
        D();
        E();
        F();
        G();
      }
      """);
  KClosedWorld world = env.kClosedWorld;

  ClassEntity A = env.getClass("A");
  ClassEntity B = env.getClass("B");
  ClassEntity C = env.getClass("C");
  ClassEntity D = env.getClass("D");
  ClassEntity E = env.getClass("E");
  ClassEntity F = env.getClass("F");
  ClassEntity G = env.getClass("G");

  void checkClass(
    ClassEntity cls, {
    bool directlyInstantiated = false,
    bool indirectlyInstantiated = false,
  }) {
    ClassHierarchyNode node = world.classHierarchy.getClassHierarchyNode(cls);
    Expect.isNotNull(node, "Expected ClassHierarchyNode for $cls.");
    Expect.equals(
      directlyInstantiated || indirectlyInstantiated,
      node.isInstantiated,
      "Unexpected `isInstantiated` on ClassHierarchyNode for $cls.",
    );
    Expect.equals(
      directlyInstantiated,
      node.isDirectlyInstantiated,
      "Unexpected `isDirectlyInstantiated` on ClassHierarchyNode for "
      "$cls.",
    );
    Expect.equals(
      indirectlyInstantiated,
      node.isIndirectlyInstantiated,
      "Unexpected `isIndirectlyInstantiated` on ClassHierarchyNode for "
      "$cls.",
    );
  }

  checkClass(A, directlyInstantiated: true, indirectlyInstantiated: true);
  checkClass(B, indirectlyInstantiated: true);
  checkClass(C, directlyInstantiated: true, indirectlyInstantiated: true);
  checkClass(D, directlyInstantiated: true);
  checkClass(E, directlyInstantiated: true);
  checkClass(F, directlyInstantiated: true);
  checkClass(G, directlyInstantiated: true);

  late ClassHierarchyNodeIterator iterator;

  void checkState(
    ClassEntity root, {
    ClassEntity? currentNode,
    List<ClassEntity>? stack,
  }) {
    ClassEntity? classOf(ClassHierarchyNode? node) {
      return node?.cls;
    }

    List<ClassEntity?>? classesOf(Iterable<ClassHierarchyNode>? list) {
      if (list == null) return null;
      return list.map(classOf).toList();
    }

    ClassEntity foundRoot = iterator.root.cls;
    ClassEntity? foundCurrentNode = classOf(iterator.currentNode);
    List<ClassEntity?>? foundStack = classesOf(iterator.stack);

    StringBuffer sb = StringBuffer();
    sb.write('{\n root: $foundRoot');
    sb.write('\n currentNode: $foundCurrentNode');
    sb.write('\n stack: $foundStack\n}');

    Expect.equals(root, foundRoot, "Expected root $root in $sb.");
    if (currentNode == null) {
      Expect.isNull(
        iterator.currentNode,
        "Unexpected non-null currentNode in $sb.",
      );
    } else {
      Expect.isNotNull(
        foundCurrentNode,
        "Expected non-null currentNode ${currentNode} in $sb.",
      );
      Expect.equals(
        currentNode,
        foundCurrentNode,
        "Expected currentNode $currentNode in $sb.",
      );
    }
    if (stack == null) {
      Expect.isNull(foundStack, "Unexpected non-null stack in $sb.");
    } else {
      Expect.isNotNull(foundStack, "Expected non-null stack ${stack} in $sb.");
      Expect.listEquals(
        stack,
        foundStack!,
        "Expected stack ${stack}, "
        "found ${foundStack} in $sb.",
      );
    }
  }

  iterator =
      ClassHierarchyNodeIterable(
        world.classHierarchy.getClassHierarchyNode(G),
        ClassHierarchyNode.all,
      ).iterator;
  checkState(G, currentNode: null, stack: null);
  Expect.isTrue(iterator.moveNext());
  checkState(G, currentNode: G, stack: []);
  Expect.isFalse(iterator.moveNext());
  checkState(G, currentNode: null, stack: []);
  Expect.throws(() => iterator.current);

  iterator =
      ClassHierarchyNodeIterable(
        world.classHierarchy.getClassHierarchyNode(G),
        ClassHierarchyNode.all,
        includeRoot: false,
      ).iterator;
  checkState(G, currentNode: null, stack: null);
  Expect.isFalse(iterator.moveNext());
  checkState(G, currentNode: null, stack: []);

  iterator =
      ClassHierarchyNodeIterable(
        world.classHierarchy.getClassHierarchyNode(C),
        ClassHierarchyNode.all,
      ).iterator;
  checkState(C, currentNode: null, stack: null);
  Expect.isTrue(iterator.moveNext());
  checkState(C, currentNode: C, stack: [G, F, E]);
  Expect.isTrue(iterator.moveNext());
  checkState(C, currentNode: E, stack: [G, F]);
  Expect.isTrue(iterator.moveNext());
  checkState(C, currentNode: F, stack: [G]);
  Expect.isTrue(iterator.moveNext());
  checkState(C, currentNode: G, stack: []);
  Expect.isFalse(iterator.moveNext());
  checkState(C, currentNode: null, stack: []);

  iterator =
      ClassHierarchyNodeIterable(
        world.classHierarchy.getClassHierarchyNode(D),
        ClassHierarchyNode.all,
      ).iterator;
  checkState(D, currentNode: null, stack: null);
  Expect.isTrue(iterator.moveNext());
  checkState(D, currentNode: D, stack: []);
  Expect.isFalse(iterator.moveNext());
  checkState(D, currentNode: null, stack: []);

  iterator =
      ClassHierarchyNodeIterable(
        world.classHierarchy.getClassHierarchyNode(B),
        ClassHierarchyNode.all,
      ).iterator;
  checkState(B, currentNode: null, stack: null);
  Expect.isTrue(iterator.moveNext());
  checkState(B, currentNode: B, stack: [D]);
  Expect.isTrue(iterator.moveNext());
  checkState(B, currentNode: D, stack: []);
  Expect.isFalse(iterator.moveNext());
  checkState(B, currentNode: null, stack: []);

  iterator =
      ClassHierarchyNodeIterable(
        world.classHierarchy.getClassHierarchyNode(B),
        ClassHierarchyNode.all,
        includeRoot: false,
      ).iterator;
  checkState(B, currentNode: null, stack: null);
  Expect.isTrue(iterator.moveNext());
  checkState(B, currentNode: D, stack: []);
  Expect.isFalse(iterator.moveNext());
  checkState(B, currentNode: null, stack: []);

  iterator =
      ClassHierarchyNodeIterable(
        world.classHierarchy.getClassHierarchyNode(B),
        EnumSet<Instantiation>.fromValues(<Instantiation>[
          Instantiation.directlyInstantiated,
          Instantiation.uninstantiated,
        ]),
      ).iterator;
  checkState(B, currentNode: null, stack: null);
  Expect.isTrue(iterator.moveNext());
  checkState(B, currentNode: D, stack: []);
  Expect.isFalse(iterator.moveNext());
  checkState(B, currentNode: null, stack: []);

  iterator =
      ClassHierarchyNodeIterable(
        world.classHierarchy.getClassHierarchyNode(A),
        ClassHierarchyNode.all,
      ).iterator;
  checkState(A, currentNode: null, stack: null);
  Expect.isTrue(iterator.moveNext());
  checkState(A, currentNode: A, stack: [C, B]);
  Expect.isTrue(iterator.moveNext());
  checkState(A, currentNode: B, stack: [C, D]);
  Expect.isTrue(iterator.moveNext());
  checkState(A, currentNode: D, stack: [C]);
  Expect.isTrue(iterator.moveNext());
  checkState(A, currentNode: C, stack: [G, F, E]);
  Expect.isTrue(iterator.moveNext());
  checkState(A, currentNode: E, stack: [G, F]);
  Expect.isTrue(iterator.moveNext());
  checkState(A, currentNode: F, stack: [G]);
  Expect.isTrue(iterator.moveNext());
  checkState(A, currentNode: G, stack: []);
  Expect.isFalse(iterator.moveNext());
  checkState(A, currentNode: null, stack: []);

  iterator =
      ClassHierarchyNodeIterable(
        world.classHierarchy.getClassHierarchyNode(A),
        ClassHierarchyNode.all,
        includeRoot: false,
      ).iterator;
  checkState(A, currentNode: null, stack: null);
  Expect.isTrue(iterator.moveNext());
  checkState(A, currentNode: B, stack: [C, D]);
  Expect.isTrue(iterator.moveNext());
  checkState(A, currentNode: D, stack: [C]);
  Expect.isTrue(iterator.moveNext());
  checkState(A, currentNode: C, stack: [G, F, E]);
  Expect.isTrue(iterator.moveNext());
  checkState(A, currentNode: E, stack: [G, F]);
  Expect.isTrue(iterator.moveNext());
  checkState(A, currentNode: F, stack: [G]);
  Expect.isTrue(iterator.moveNext());
  checkState(A, currentNode: G, stack: []);
  Expect.isFalse(iterator.moveNext());
  checkState(A, currentNode: null, stack: []);

  iterator =
      ClassHierarchyNodeIterable(
        world.classHierarchy.getClassHierarchyNode(A),
        EnumSet<Instantiation>.fromValues(<Instantiation>[
          Instantiation.directlyInstantiated,
          Instantiation.uninstantiated,
        ]),
      ).iterator;
  checkState(A, currentNode: null, stack: null);
  Expect.isTrue(iterator.moveNext());
  checkState(A, currentNode: A, stack: [C, B]);
  Expect.isTrue(iterator.moveNext());
  checkState(A, currentNode: D, stack: [C]);
  Expect.isTrue(iterator.moveNext());
  checkState(A, currentNode: C, stack: [G, F, E]);
  Expect.isTrue(iterator.moveNext());
  checkState(A, currentNode: E, stack: [G, F]);
  Expect.isTrue(iterator.moveNext());
  checkState(A, currentNode: F, stack: [G]);
  Expect.isTrue(iterator.moveNext());
  checkState(A, currentNode: G, stack: []);
  Expect.isFalse(iterator.moveNext());
  checkState(A, currentNode: null, stack: []);

  iterator =
      ClassHierarchyNodeIterable(
        world.classHierarchy.getClassHierarchyNode(A),
        EnumSet<Instantiation>.fromValues(<Instantiation>[
          Instantiation.directlyInstantiated,
          Instantiation.uninstantiated,
        ]),
        includeRoot: false,
      ).iterator;
  checkState(A, currentNode: null, stack: null);
  Expect.isTrue(iterator.moveNext());
  checkState(A, currentNode: D, stack: [C]);
  Expect.isTrue(iterator.moveNext());
  checkState(A, currentNode: C, stack: [G, F, E]);
  Expect.isTrue(iterator.moveNext());
  checkState(A, currentNode: E, stack: [G, F]);
  Expect.isTrue(iterator.moveNext());
  checkState(A, currentNode: F, stack: [G]);
  Expect.isTrue(iterator.moveNext());
  checkState(A, currentNode: G, stack: []);
  Expect.isFalse(iterator.moveNext());
  checkState(A, currentNode: null, stack: []);
}

testForEach() async {
  var env = await TypeEnvironment.create(r"""
      ///        A
      ///       / \
      ///      B   C
      ///     /   /|\
      ///    D   E F G
      ///         / \
      ///         H I
      ///
      class A implements X {}
      class B extends A {}
      class C extends A {}
      class D extends B {}
      class E extends C {}
      class F extends C implements B {}
      class G extends C implements D {}
      class H extends F {}
      class I extends F {}
      class X {}

      main() {
        A();
        C();
        D();
        E();
        F();
        G();
        H();
        I();
      }
      """);
  KClosedWorld world = env.kClosedWorld;

  ClassEntity A = env.getClass("A");
  ClassEntity B = env.getClass("B");
  ClassEntity C = env.getClass("C");
  ClassEntity D = env.getClass("D");
  ClassEntity E = env.getClass("E");
  ClassEntity F = env.getClass("F");
  ClassEntity G = env.getClass("G");
  ClassEntity H = env.getClass("H");
  ClassEntity I = env.getClass("I");
  ClassEntity X = env.getClass("X");

  void checkForEachSubclass(ClassEntity cls, List<ClassEntity> expected) {
    ClassSet classSet = world.classHierarchy.getClassSet(cls);
    List<ClassEntity> visited = <ClassEntity>[];
    classSet.forEachSubclass((cls) {
      visited.add(cls);
      return IterationStep.continue_;
    }, ClassHierarchyNode.all);

    Expect.listEquals(
      expected,
      visited,
      "Unexpected classes on $cls.forEachSubclass:\n"
      "Actual: $visited, expected: $expected\n$classSet",
    );

    visited = <ClassEntity>[];
    classSet.forEachSubclass((cls) {
      visited.add(cls);
      return IterationStep.continue_;
    }, ClassHierarchyNode.all);

    Expect.listEquals(
      expected,
      visited,
      "Unexpected classes on $cls.forEachSubclass:\n"
      "Actual: $visited, expected: $expected\n$classSet",
    );
  }

  checkForEachSubclass(A, [A, B, D, C, E, F, H, I, G]);
  checkForEachSubclass(B, [B, D]);
  checkForEachSubclass(C, [C, E, F, H, I, G]);
  checkForEachSubclass(D, [D]);
  checkForEachSubclass(E, [E]);
  checkForEachSubclass(F, [F, H, I]);
  checkForEachSubclass(G, [G]);
  checkForEachSubclass(H, [H]);
  checkForEachSubclass(I, [I]);
  checkForEachSubclass(X, [X]);

  void checkForEachSubtype(ClassEntity cls, List<ClassEntity> expected) {
    ClassSet classSet = world.classHierarchy.getClassSet(cls);
    List<ClassEntity> visited = <ClassEntity>[];
    classSet.forEachSubtype((cls) {
      visited.add(cls);
      return IterationStep.continue_;
    }, ClassHierarchyNode.all);

    Expect.listEquals(
      expected,
      visited,
      "Unexpected classes on $cls.forEachSubtype:\n"
      "Actual: $visited, expected: $expected\n$classSet",
    );

    visited = <ClassEntity>[];
    classSet.forEachSubtype((cls) {
      visited.add(cls);
      return IterationStep.continue_;
    }, ClassHierarchyNode.all);

    Expect.listEquals(
      expected,
      visited,
      "Unexpected classes on $cls.forEachSubtype:\n"
      "Actual: $visited, expected: $expected\n$classSet",
    );
  }

  checkForEachSubtype(A, [A, B, D, C, E, F, H, I, G]);
  checkForEachSubtype(B, [B, D, F, H, I, G]);
  checkForEachSubtype(C, [C, E, F, H, I, G]);
  checkForEachSubtype(D, [D, G]);
  checkForEachSubtype(E, [E]);
  checkForEachSubtype(F, [F, H, I]);
  checkForEachSubtype(G, [G]);
  checkForEachSubtype(H, [H]);
  checkForEachSubtype(I, [I]);
  checkForEachSubtype(X, [X, A, B, D, C, E, F, H, I, G]);

  void checkForEach(
    ClassEntity cls,
    List<ClassEntity> expected, {
    ClassEntity? stop,
    List<ClassEntity> skipSubclasses = const <ClassEntity>[],
    bool forEachSubtype = false,
    EnumSet<Instantiation>? mask,
  }) {
    if (mask == null) {
      mask = ClassHierarchyNode.all;
    }

    ClassSet classSet = world.classHierarchy.getClassSet(cls);
    List<ClassEntity> visited = <ClassEntity>[];

    IterationStep visit(_cls) {
      ClassEntity cls = _cls;
      visited.add(cls);
      if (cls == stop) {
        return IterationStep.stop;
      } else if (skipSubclasses.contains(cls)) {
        return IterationStep.skipSubclasses;
      }
      return IterationStep.continue_;
    }

    if (forEachSubtype) {
      classSet.forEachSubtype(visit, mask);
    } else {
      classSet.forEachSubclass(visit, mask);
    }

    Expect.listEquals(
      expected,
      visited,
      "Unexpected classes on $cls."
      "forEach${forEachSubtype ? 'Subtype' : 'Subclass'} "
      "(stop:$stop, skipSubclasses:$skipSubclasses):\n"
      "Actual: $visited, expected: $expected\n$classSet",
    );
  }

  checkForEach(A, [A, B, D, C, E, F, H, I, G]);
  checkForEach(A, [A], stop: A);
  checkForEach(A, [A, B, C, E, F, H, I, G], skipSubclasses: [B]);
  checkForEach(A, [A, B, C], skipSubclasses: [B, C]);
  checkForEach(A, [A, B, C, E, F], stop: F, skipSubclasses: [B]);

  checkForEach(B, [B, D, F, H, I, G], forEachSubtype: true);
  checkForEach(B, [B, D], stop: D, forEachSubtype: true);
  checkForEach(B, [B, D, F, G], skipSubclasses: [F], forEachSubtype: true);
  checkForEach(B, [B, F, H, I, G], skipSubclasses: [B], forEachSubtype: true);
  checkForEach(
    B,
    [B, D, F, H, I, G],
    skipSubclasses: [D],
    forEachSubtype: true,
  );

  checkForEach(X, [X, A, B, D, C, E, F, H, I, G], forEachSubtype: true);
  checkForEach(X, [X, A, B, D], stop: D, forEachSubtype: true);
  checkForEach(
    X,
    [X, A, B, D, C, E, F, G],
    skipSubclasses: [F],
    forEachSubtype: true,
  );
  checkForEach(
    X,
    [X, A, B, D, C, E, F, H, I, G],
    skipSubclasses: [X],
    forEachSubtype: true,
  );
  checkForEach(
    X,
    [X, A, B, D, C, E, F, H, I, G],
    skipSubclasses: [D],
    forEachSubtype: true,
  );
  checkForEach(
    X,
    [A, D, C, E, F, H, I, G],
    forEachSubtype: true,
    mask: ClassHierarchyNode.explicitlyInstantiated,
  );
  checkForEach(
    X,
    [A, B, D, C, E, F, H, I, G],
    forEachSubtype: true,
    mask: ClassHierarchyNode.instantiated,
  );

  void checkAny(
    ClassEntity cls,
    List<ClassEntity> expected, {
    ClassEntity? find,
    required bool expectedResult,
    bool anySubtype = false,
  }) {
    ClassSet classSet = world.classHierarchy.getClassSet(cls);
    List<ClassEntity> visited = <ClassEntity>[];

    bool visit(cls) {
      visited.add(cls);
      return cls == find;
    }

    bool result;
    if (anySubtype) {
      result = classSet.anySubtype(visit, ClassHierarchyNode.all);
    } else {
      result = classSet.anySubclass(visit, ClassHierarchyNode.all);
    }

    Expect.equals(
      expectedResult,
      result,
      "Unexpected result on $cls."
      "any${anySubtype ? 'Subtype' : 'Subclass'} "
      "(find:$find).",
    );

    Expect.listEquals(
      expected,
      visited,
      "Unexpected classes on $cls."
      "any${anySubtype ? 'Subtype' : 'Subclass'} "
      "(find:$find):\n"
      "Actual: $visited, expected: $expected\n$classSet",
    );
  }

  checkAny(A, [A, B, D, C, E, F, H, I, G], expectedResult: false);
  checkAny(A, [A], find: A, expectedResult: true);
  checkAny(A, [A, B, D, C, E, F, H], find: H, expectedResult: true);

  checkAny(B, [B, D, F, H, I, G], anySubtype: true, expectedResult: false);
  checkAny(
    B,
    [B, D, F, H, I, G],
    find: A,
    anySubtype: true,
    expectedResult: false,
  );
  checkAny(B, [B, D], find: D, anySubtype: true, expectedResult: true);
  checkAny(B, [B, D, F, H, I], find: I, anySubtype: true, expectedResult: true);

  checkAny(
    X,
    [X, A, B, D, C, E, F, H, I, G],
    anySubtype: true,
    expectedResult: false,
  );
  checkAny(X, [X, A], find: A, anySubtype: true, expectedResult: true);
  checkAny(X, [X, A, B, D], find: D, anySubtype: true, expectedResult: true);
  checkAny(
    X,
    [X, A, B, D, C, E, F, H, I],
    find: I,
    anySubtype: true,
    expectedResult: true,
  );
}

testClosures() async {
  var env = await TypeEnvironment.create(r"""
      class A {
        call() => null;
      }

      main() {
        A();
        () {};
        local() {}
      }
      """, testBackendWorld: true);
  JClosedWorld world = env.jClosedWorld;

  ClassEntity functionClass = world.commonElements.functionClass;
  ClassEntity closureClass = world.commonElements.closureClass;
  ClassEntity A = env.getClass("A");

  IterationStep checkIsFunction(ClassEntity cls, {bool expected = true}) {
    Expect.equals(
      expected,
      world.classHierarchy.isSubtypeOf(cls, functionClass),
      "Expected $cls ${expected ? '' : 'not '}to be a subtype "
      "of $functionClass.",
    );
    return IterationStep.continue_;
  }

  checkIsFunction(A, expected: false);

  world.classHierarchy.forEachStrictSubtypeOf(closureClass, checkIsFunction);
}
