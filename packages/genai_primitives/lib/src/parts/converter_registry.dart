import 'message_parts.dart';

/// Converter registry.
///
/// The key of a map entry is the part type.
/// The value is the converter that knows how to convert that part type.
const defaultPartConverterRegistry = <String, JsonToPartConverter>{
  _Part.text: PartConverter(TextPart.fromJson),
  _Part.data: PartConverter(DataPart.fromJson),
  _Part.link: PartConverter(LinkPart.fromJson),
  _Part.tool: PartConverter(ToolPart.fromJson),
};

typedef _JsonToPartFunction = Part Function(Map<String, Object?> json);

/// A converter that converts a JSON map to a [Part].
@visibleForTesting
class PartConverter extends JsonToPartConverter {
  const PartConverter(this._function);

  final _JsonToPartFunction _function;

  @override
  Part convert(Map<String, Object?> input) {
    return _function(input);
  }
}
