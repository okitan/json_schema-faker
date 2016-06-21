RSpec.describe JsonSchema::Faker do
  context "generate" do
    let(:raw_schema) do
      {
        "id"         => self.__id__.to_s,
        "$schema"    => "http://json-schema.org/draft-04/schema#",
        "properties" => {
          "a" => { "enum" => [ "a", "aa" ] },
          "b" => { "enum" => [ "b" ]},
          "c" => {
            "properties" => {
              "a" => { "enum" => [ "a", "aa"] },
              "b" => { "enum" => [ "b" ] },
            },
            "required" => [ "c"],
          }
        },
        "required"   => [ "a", "b" ],
      }
    end

    let(:schema) do
      schema = JsonSchema.parse!(raw_schema)
      schema.expand_references!
      schema
    end

    it "works"  do
      expect(described_class.new(schema).generate).to eq("a" => "a", "b" => "b")
    end

    it "works with hint" do
      ex = { "a" => "aa" }
      expect(described_class.new(schema).generate(hint: { example: ex })).to eq("a" => "aa", "b" => "b")
    end
  end

  # TODO: switch strategy
  [ JsonSchema::Faker::Strategy::Simple ].each do |strategy|
    it_behaves_like "strategy" do
      let(:strategy) { strategy.new }
    end
  end
end
