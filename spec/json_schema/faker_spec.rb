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
          "integer"              => { "type" => "integer" },
          "integer_with_mininum" => { "type" => "integer", "minimum" => 10 },
          "integer_with_maximum" => { "type" => "integer", "maximum" => -10 },
          "integer_with_minmax"  => { "type" => "integer", "minimum" => 2, "maximum" => 3 },
          "multiple"              => { "type" => "integer", "multipleOf" => 3 },
          "multiple_with_minimum" => { "type" => "integer", "multipleOf" => 3, "minimum" => 2 },
          "multiple_with_maximum" => { "type" => "integer", "multipleOf" => 3, "minimum" => -4 },
          "multiple_with_minmax"  => { "type" => "integer", "multipleOf" => 3, "minimum" => 2, "maximum" => 4 },
          # TODO: add test about exclusiveMinimum, exclusiveMaximum
        }
      end
    end
  end
end
