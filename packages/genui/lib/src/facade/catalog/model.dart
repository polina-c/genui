import '../../../genui.dart';

abstract class UiDefinition {}

abstract class UiSchema<T extends UiDefinition> {
  T parse(JsonMap json);
}
