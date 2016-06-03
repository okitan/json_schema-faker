# this requires properties and strategy
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
    expect(described_class.new(@schema, strategy: strategy).generate).to be_valid_for(@schema)
  end
end
