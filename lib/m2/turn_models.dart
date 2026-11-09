import 'package:flutter/foundation.dart';

/// One assistant part inside a turn: a text segment or a tool/other row.
@immutable
class TurnPart {
  const TurnPart.text(this.text, this.streaming, this.row)
      : type = PartType.text;
  const TurnPart.row(this.row)
      : type = PartType.row,
        text = null,
        streaming = false;

  final PartType type;
  final String? text;
  final bool streaming;
  final Map<String, dynamic>? row;
}

enum PartType { text, row }

/// A conversation turn: optional user bubble + turn header (state/tokens/
/// fileChanges) + ordered assistant parts. Mirrors the web timeline.
@immutable
class TurnGroup {
  const TurnGroup({this.userRow, this.header, required this.parts});

  final Map<String, dynamic>? userRow;
  final Map<String, dynamic>? header;
  final List<TurnPart> parts;

  bool get streaming => parts.any((p) => p.streaming);
}

/// Groups raw ConversationState rows into renderable turns.
///
/// Port of zic's groupTurnRows + assistantTurnParts, simplified for M2:
/// a `userInput` row starts a new turn; consecutive `assistantText` rows
/// merge into one text part (\n\n joined, streaming if any row was);
/// `toolCall`/other rows become their own part in stream order. The
/// `turnHeader` row is lifted out to render at the top of the turn.
List<TurnGroup> groupTurns(List<Map<String, dynamic>> rows) {
  final groups = <TurnGroup>[];
  Map<String, dynamic>? userRow;
  Map<String, dynamic>? header;
  final parts = <TurnPart>[];
  final buf = StringBuffer();
  var streaming = false;
  Map<String, dynamic>? textTemplate;

  void flushText() {
    final text = buf.toString().trim();
    if (text.isNotEmpty) {
      parts.add(TurnPart.text(text, streaming, textTemplate));
    }
    buf.clear();
    streaming = false;
    textTemplate = null;
  }

  void flushGroup() {
    flushText();
    if (userRow != null || header != null || parts.isNotEmpty) {
      // Copy: `parts` is reused (cleared) for the next group — sharing the
      // reference would empty every emitted turn.
      groups.add(TurnGroup(
        userRow: userRow,
        header: header,
        parts: List<TurnPart>.of(parts),
      ));
    }
    userRow = null;
    header = null;
    parts.clear();
  }

  for (final row in rows) {
    switch (row['kind']) {
      case 'userInput':
        flushGroup();
        userRow = row;
      case 'turnHeader':
        header = row;
      case 'assistantText':
        textTemplate ??= row;
        if (buf.isNotEmpty) buf.write('\n\n');
        buf.write(row['text'] as String? ?? '');
        if (row['state'] == 'streaming') streaming = true;
      case 'timelineMarker':
      case 'hookInvocation':
      case 'pendingThinking':
        // M2: markers/hooks render inside the log tab, not the timeline.
        break;
      default:
        // toolCall, subagent, and any future kinds render as row parts.
        flushText();
        parts.add(TurnPart.row(row));
    }
  }
  flushGroup();
  return groups;
}
