require "json_schema/faker/strategy/greedy"

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
            "required" => [ "a", "b" ],
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
      ex = { "a" => "aa", "c" => { "a" => "aa" } }
      expect(described_class.new(schema).generate(hint: { example: ex })).to eq("a" => "aa", "b" => "b", "c" => { "a" => "aa", "b" => "b" })
    end
  end

  # TODO: switch strategy
  [ JsonSchema::Faker::Strategy::Simple, JsonSchema::Faker::Strategy::Greedy ].each do |strategy|
    context "with #{strategy}" do
      it_behaves_like "strategy" do
        before do |example|
          if strategy == ::JsonSchema::Faker::Strategy::Greedy && example.metadata[:test]
            skip "do not support invalid schema"                  if example.metadata[:test].start_with?("suite/tests/draft4/default.json")
            skip "not is difficult"                               if example.metadata[:test] == "suite/tests/draft4/not.json[3]"
            skip "combinatio withpattern properties is difficult" if example.metadata[:test] == "suite/tests/draft4/properties.json[1]"
          end
        end

        let(:strategy) { strategy.new }
      end
    end
  end
end
