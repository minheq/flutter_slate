import 'package:flutter_test/flutter_test.dart';
import 'package:inday/stela/editor.dart';
import 'package:inday/stela/element.dart';
import 'package:inday/stela/node.dart';
import 'package:inday/stela/operation.dart';
import 'package:inday/stela/range.dart';
import 'package:inday/stela/text.dart';

class TestEditor extends Editor {
  TestEditor(
      {List<Node> children,
      Range selection,
      List<Operation> operations,
      Map<String, dynamic> marks,
      Map<String, dynamic> props})
      : super(
            children: children,
            selection: selection,
            operations: operations,
            marks: marks,
            props: props);

  @override
  bool isInline(Element element) {
    return element is Inline;
  }

  @override
  bool isVoid(Element element) {
    return element is Void;
  }
}

void main() {
  group('block', () {
    test('insert text', () {
      // <editor>
      //   <block />
      // </editor>
      Block block = Block(children: <Node>[]);
      TestEditor editor = TestEditor(children: <Node>[block]);

      EditorUtils.normalize(editor, force: true);

      // <editor>
      //   <block>
      //     <text />
      //   </block>
      // </editor>
      expect(block.children[0] is Text, true);
      expect((block.children[0] as Text).text, '');
    });

    test('remove block', () {
      // <editor>
      //   <block>
      //     <text>one</text>
      //     <block>two</block>
      //   </block>
      // </editor>
      Block block = Block(children: <Node>[
        Text('one'),
        Block(children: <Node>[Text('two')])
      ]);
      TestEditor editor = TestEditor(children: <Node>[block]);

      EditorUtils.normalize(editor, force: true);

      // <editor>
      //   <block>
      //     <text>one</text>
      //   </block>
      // </editor>
      expect(block.children.length, 1);
      expect(block.children[0] is Text, true);
      expect((block.children[0] as Text).text, 'one');
    });

    test('remove inline', () {
      // <editor>
      //   <block>
      //     <block>one</block>
      //     <inline>two</inline>
      //   </block>
      // </editor>
      Block block = Block(children: <Node>[
        Block(children: <Node>[Text('one')]),
        Inline(children: <Node>[Text('two')])
      ]);
      TestEditor editor = TestEditor(children: <Node>[block]);

      EditorUtils.normalize(editor, force: true);

      // <editor>
      //   <block>
      //     <block>one</block>
      //   </block>
      // </editor>
      Block innerBlock = block.children[0];
      expect(block.children.length, 1);
      expect((innerBlock.children[0] as Text).text, 'one');
    });
  });

  group('editor', () {
    test('remove inline', () {
      // <editor>
      //   <inline>one</inline>
      //   <block>two</block>
      // </editor>

      TestEditor editor = TestEditor(children: <Node>[
        Inline(children: <Node>[Text('one')]),
        Block(children: <Node>[Text('two')])
      ]);

      EditorUtils.normalize(editor, force: true);

      // <editor>
      //   <block>two</block>
      // </editor>
      Block block = editor.children[0];
      expect(editor.children.length, 1);
      expect((block.children[0] as Text).text, 'two');
    });

    test('remove text', () {
      // <editor>
      //   <text>one</text>
      //   <block>two</block>
      // </editor>

      TestEditor editor = TestEditor(children: <Node>[
        Text('one'),
        Block(children: <Node>[Text('two')])
      ]);

      EditorUtils.normalize(editor, force: true);

      // <editor>
      //   <block>two</block>
      // </editor>
      Block block = editor.children[0];
      expect(editor.children.length, 1);
      expect((block.children[0] as Text).text, 'two');
    });
  });

  group('inline', () {
    test('insert adjacent text', () {
      // <editor>
      //   <block>
      //     <inline>one</inline>
      //     <inline>two</inline>
      //   </block>
      // </editor>
      Block block = Block(children: <Node>[
        Inline(children: <Node>[Text('one')]),
        Inline(children: <Node>[Text('two')]),
      ]);
      TestEditor editor = TestEditor(children: <Node>[block]);

      EditorUtils.normalize(editor, force: true);

      // <editor>
      //   <block>
      //     <text />
      //     <inline>one</inline>
      //     <text />
      //     <inline>two</inline>
      //     <text />
      //   </block>
      // </editor>
      expect(block.children.length, 5);
      expect((block.children[0] as Text).text, '');
      expect(((block.children[1] as Inline).children[0] as Text).text, 'one');
      expect((block.children[2] as Text).text, '');
      expect(((block.children[3] as Inline).children[0] as Text).text, 'two');
      expect((block.children[4] as Text).text, '');
    });

    test('remove block', () {
      // <editor>
      //   <block>
      //     <text />
      //     <inline>
      //       <block>one</block>
      //       <text>two</text>
      //     </inline>
      //     <text />
      //   </block>
      // </editor>
      Block block = Block(children: <Node>[
        Text(''),
        Inline(children: <Node>[
          Block(children: <Node>[Text('one')]),
          Text('two'),
        ]),
        Text(''),
      ]);
      TestEditor editor = TestEditor(children: <Node>[block]);

      EditorUtils.normalize(editor, force: true);

      // <editor>
      //   <block>
      //     <text />
      //     <inline>
      //       <text>two</text>
      //     </inline>
      //     <text />
      //   </block>
      // </editor>
      expect(block.children.length, 3);
      expect((block.children[0] as Text).text, '');
      expect(((block.children[1] as Inline).children[0] as Text).text, 'two');
      expect((block.children[2] as Text).text, '');
    });
  });

  group('text', () {
    test('merge adjacent empty', () {
      // <editor>
      //   <block>
      //     <text />
      //     <text />
      //   </block>
      // </editor>
      Block block = Block(children: <Node>[
        Text(''),
        Text(''),
      ]);
      TestEditor editor = TestEditor(children: <Node>[block]);

      EditorUtils.normalize(editor, force: true);

      // <editor>
      //   <block>
      //     <text />
      //   </block>
      // </editor>
      expect(block.children.length, 1);
      expect((block.children[0] as Text).text, '');
    });

    test('merge adjacent match empty', () {
      // <editor>
      //   <block>
      //     <text>1</text>
      //     <text>2</text>
      //   </block>
      // </editor>
      Block block = Block(children: <Node>[
        Text('1'),
        Text('2'),
      ]);
      TestEditor editor = TestEditor(children: <Node>[block]);

      EditorUtils.normalize(editor, force: true);

      // <editor>
      //   <block>
      //     <text>12</text>
      //   </block>
      // </editor>
      expect(block.children.length, 1);
      expect((block.children[0] as Text).text, '12');
    });

    test('merge adjacent match', () {
      // <editor>
      //   <block>
      //     <text a>1</text>
      //     <text a>2</text>
      //   </block>
      // </editor>
      Block block = Block(children: <Node>[
        Text('1', props: {'a': true}),
        Text('2', props: {'a': true}),
      ]);
      TestEditor editor = TestEditor(children: <Node>[block]);

      EditorUtils.normalize(editor, force: true);

      // <editor>
      //   <block>
      //     <text>12</text>
      //   </block>
      // </editor>
      expect(block.children.length, 1);
      expect((block.children[0] as Text).text, '12');
    });
  });

  group('void', () {
    test('block insert text', () {
      // <editor>
      //   <void />
      // </editor>
      Void v = Void(children: <Node>[]);
      TestEditor editor = TestEditor(children: <Node>[v]);

      EditorUtils.normalize(editor, force: true);

      // <editor>
      //   <void>
      //     <text />
      //   </void>
      // </editor>
      expect(v.children.length, 1);
      expect((v.children[0] as Text).text, '');
    });

    test('inline insert text', () {
      // <editor>
      //   <text />
      //   <void />
      //   <text />
      // </editor>
      Void v = Void(children: <Node>[]);
      TestEditor editor = TestEditor(children: <Node>[Text(''), v, Text('')]);

      EditorUtils.normalize(editor, force: true);

      // <editor>
      //   <block>
      //     <text />
      //     <void>
      //       <text />
      //     </void>
      //     <text />
      //   </block>
      // </editor>
      expect(v.children.length, 1);
      expect((v.children[0] as Text).text, '');
    });
  });
}
