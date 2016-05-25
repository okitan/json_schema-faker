RSpec::Matchers.define :be_valid_for do |schema|
  match do |actual|
    schema.validate(actual).first
  end

  failure_message do |actual|
    errors = schema.validate(actual).last

    "expected that #{actual} would be valid for #{schema.inspect_schema}:\n  " + errors.join("\n  ")
  end
end


# this requires properties
RSpec.shared_examples "generating data from properties which passes validation" do
  it do
    raw_schema = {
      "id"         => self.__id__.to_s,
      "$schema"    => "http://json-schema.org/draft-04/schema#",
      "properties" => properties,
      "required"   => properties.keys,
    }

    @schema = JsonSchema.parse!(raw_schema)
    @schema.expand_references!
    expect(described_class.new(@schema).generate).to be_valid_for(@schema)
  end
end

RSpec.describe JsonSchema::Faker do
  context "#generate" do
    it_behaves_like "generating data from properties which passes validation" do
      let(:properties) do
        {
          "an_object"            => {},
          "array"                   => { "type" => "array" },
          "array_without_items"     => { "type" => "array", "minItems" => 1 },
          "array_with_length"       => { "type" => "array", "minItems" => 1 },
          "array_everything_ok"     => { "type" => "array", "minItems" => 1, "items" => [ {} ], "additionalItems" => true },
          "array_everything_ok2"    => { "type" => "array", "minItems" => 1, "items" => [ {} ], "additionalItems" => {} },
          "array_with_object_items" => { "type" => "array", "minItems" => 1, "items" => {},     "additionalItems" => false },
          "array_with_items"        => { "type" => "array", "minItems" => 1, "items" => [ {} ],   "additionalItems" => false },
          "array_with_items2"       => { "type" => "array", "minItems" => 2, "items" => [ { "enum" => [ 1 ] }, { "type" => "string" } ], "additionalItems" => false },
          "boolean"              => { "type" => "boolean" },
          "integer"              => { "type" => "integer" },
          "integer_with_minimum" => { "type" => "integer", "minimum" => 10 },
          "integer_with_maximum" => { "type" => "integer", "maximum" => -10 },
          "integer_with_minmax"  => { "type" => "integer", "minimum" => 2, "maximum" => 3 },
          "multiple"              => { "type" => "integer", "multipleOf" => 3 },
          "multiple_with_minimum" => { "type" => "integer", "multipleOf" => 3, "minimum" => 2 },
          "multiple_with_maximum" => { "type" => "integer", "multipleOf" => 3, "minimum" => -4 },
          "multiple_with_minmax"  => { "type" => "integer", "multipleOf" => 3, "minimum" => 2, "maximum" => 4 },
          # TODO: add test about exclusiveMinimum, exclusiveMaximum
          "number"              => { "type" => "number" },
          "number_with_minmax"  => { "type" => "number", "minimum" => 2, "maximum" => 3, "exclusiveMinimum" => true, "exclusiveMaximum" => true },
          "null"                => { "type" => "null" },
          "string"              => { "type" => "string" },
          "string_with_min"     => { "type" => "string", "minLength" => 1 },
          "string_with_max"     => { "type" => "string", "maxLength" => 255 },
          "string_with_minmax"  => { "type" => "string", "minLength" => 254, "maxLength" => 255 },
          "string_with_pattern" => { "type" => "string", "pattern" => "^\w+$" },
        }
      end
    end
  end
end
