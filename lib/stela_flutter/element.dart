import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:inday/stela/stela.dart' as Stela;
import 'package:inday/stela_flutter/editable.dart';
import 'package:inday/stela_flutter/rich_text.dart';
import 'package:inday/stela_flutter/children.dart';
import 'package:inday/stela_flutter/editor.dart';

class StelaElement extends StatefulWidget {
  StelaElement(
      {Key key,
      @required this.node,
      this.elementBuilder,
      this.textBuilder,
      this.selection})
      : assert(node != null),
        assert(elementBuilder != null),
        assert(textBuilder != null),
        super(key: key);

  final Stela.Ancestor node;
  final Widget Function(Stela.Element element, StelaChildren children)
      elementBuilder;
  final TextSpan Function(Stela.Text text) textBuilder;
  final Stela.Range selection;

  @override
  _StelaElementState createState() => _StelaElementState();
}

class _StelaElementState extends State<StelaElement> {
  @override
  Widget build(BuildContext context) {
    StelaEditableScope editableScope = StelaEditableScope.of(context);

    bool isRichText =
        widget.node is Stela.Block && widget.node.children.first is Stela.Text;

    if (isRichText == false) {
      return widget.elementBuilder(
          widget.node,
          StelaChildren(
            node: widget.node,
            elementBuilder: widget.elementBuilder,
            textBuilder: widget.textBuilder,
            selection: widget.selection,
          ));
    }

    List<InlineSpan> children = [];

    for (Stela.Node child in widget.node.children) {
      if (child is Stela.Text) {
        children.add(widget.textBuilder(child));
      } else {
        throw Exception('Inline not supported');
      }
    }

    TextSelection textSelection;

    if (widget.selection != null) {
      textSelection = TextSelection(
          baseOffset: widget.selection.anchor.offset,
          extentOffset: widget.selection.focus.offset);
    }

    return StelaRichText(
      node: widget.node,
      text: TextSpan(children: children),
      selection: textSelection,
      showCursor: editableScope.showCursor,
      editableScope: editableScope,
      cursorColor: editableScope.cursorColor,
      hasFocus: editableScope.hasFocus,
      cursorRadius: editableScope.cursorRadius,
    );
  }
}

class DefaultElement extends StatelessWidget {
  DefaultElement({this.element, this.children});

  final Stela.Element element;
  final StelaChildren children;

  @override
  Widget build(BuildContext context) {
    return Container(child: children);
  }
}
