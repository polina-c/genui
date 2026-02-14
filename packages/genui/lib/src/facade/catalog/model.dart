import 'package:json_schema_builder/json_schema_builder.dart';

import '../../../genui.dart';

abstract class ComponentDefinition {}

abstract class ComponentSchema<T extends ComponentDefinition> {
  ComponentSchema(this.schema);

  final Schema schema;

  T parse(JsonMap json);
}
