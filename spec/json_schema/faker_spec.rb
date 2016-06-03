RSpec.describe JsonSchema::Faker do
  context "generate" do
    let(:raw_schema) do
      {
        "id"         => self.__id__.to_s,
        "$schema"    => "http://json-schema.org/draft-04/schema#",
        "properties" => {
          "a" => { "enum" => [ "a" ] }
        },
        "required"   => [ "a" ],
      }
    end

    let(:schema) do
      schema = JsonSchema.parse!(raw_schema)
      schema.expand_references!
      schema
    end

    it "works", :aggregate_failures do
      expect(described_class.new(schema).generate).to eq("a" => "a")
    end
  end

  # TODO: switch strategy
  [ JsonSchema::Faker::Strategy::Simple ].each do |strategy|
    it_behaves_like "strategy" do
      let(:strategy) { strategy.new }
    end
  end
end
