require "json_schema/faker/strategy/greedy"
require "json_schema/faker/util"

::RSpec.describe ::JsonSchema::Faker::Util do
  context ".compare_schema" do
    tests = {
      "object" => [ {}, {}, true ],
      "simple_match"    => [ { "minimum" => 10 }, { "minimum" => 10 }, true ],
      "simple_no_match" => [ { "minimum" => 10 }, { "minimum" => 20 }, false ],
      "key_order" => [ { "minimum" => 10, "maximum" => 10 }, { "maximum" => 10, "minimum" => 10 }, true ],
    }

    tests.each do |name, (a, b, answer)|
      a_schema      = ::JsonSchema.parse!(a)
      b_schema      = ::JsonSchema.parse!(b)

      context "#{name} test" do
        it "works" do
          expect(described_class.compare_schema(a_schema, b_schema)).to eq(answer)
        end
      end
    end

    context "which have reference" do
      store = ::JsonSchema::DocumentStore.new
      schema = ::JsonSchema.parse!(
        "id" => "https://example.com/schema.json",
        "definitions" => {
          "a" => { "type" => "integer" },
          "b" => { "type" => "integer" },
          "c" => { "type" => "string"  },
          "d" => { "$ref" => "#/definitions/a" },
          "e" => { "$ref" => "#/definitions/c" }
        }
      )
      schema.expand_references!
      store.add_schema(schema)

      tests = {
        "same_pointer"     => [ { "$ref" => "https://example.com/schema.json#/definitions/a" }, { "$ref" => "https://example.com/schema.json#/definitions/a" }, true ],
        "same_schema"      => [ { "$ref" => "https://example.com/schema.json#/definitions/a" }, { "$ref" => "https://example.com/schema.json#/definitions/b" }, true ],
        "different_schema" => [ { "$ref" => "https://example.com/schema.json#/definitions/a" }, { "$ref" => "https://example.com/schema.json#/definitions/c" }, false ],
        "recursive_schema" => [ { "$ref" => "https://example.com/schema.json#/definitions/a" }, { "$ref" => "https://example.com/schema.json#/definitions/d" }, true ],
        "diffrerent_recursive_schema" => [ { "$ref" => "https://example.com/schema.json#/definitions/d" }, { "$ref" => "https://example.com/schema.json#/definitions/e" }, false ],
      }

      tests.each do |name, (a, b, answer)|
        a_schema      = ::JsonSchema.parse!(a)
        a_schema.expand_references!(store: store)
        b_schema      = ::JsonSchema.parse!(b)
        b_schema.expand_references!(store: store)

        context "#{name} test" do
          it "works" do
            expect(described_class.compare_schema(a_schema, b_schema)).to eq(answer)
          end
        end
      end
    end
  end

  context ".take_logical_and_of_schema!" do
    tests =  {
      # for number
      "minimum"  => [ { "minimum" =>  10 }, { "minimum" =>  20 }, { "minimum" =>  20 } ],
      "minimum_exclusive1"  => [ { "minimum" => 10, "exclusiveMinimum" => true }, { "minimum" => 20 }, { "minimum" =>  20 } ],
      "minimum_exclusive2"  => [ { "minimum" => 10 }, { "minimum" => 20, "exclusiveMinimum" => true }, { "minimum" =>  20, "exclusiveMinimum" => true } ],
      "minimum_exclusive3"  => [ { "minimum" => 10 }, { "minimum" => 10, "exclusiveMinimum" => true }, { "minimum" =>  10, "exclusiveMinimum" => true } ],
      "maximum"  => [ { "maximum" => -10 }, { "maximum" => -20 }, { "maximum" => -20 } ],
      "maximum_exclusive1"  => [ { "maximum" => -10, "exclusiveMaximum" => true }, { "maximum" => -20 }, { "maximum" => -20 } ],
      "maximum_exclusive2"  => [ { "maximum" => -10 }, { "maximum" => -20, "exclusiveMaximum" => true }, { "maximum" => -20, "exclusiveMaximum" => true } ],
      "maximum_exclusive3"  => [ { "maximum" => -10 }, { "maximum" => -10, "exclusiveMaximum" => true }, { "maximum" => -10, "exclusiveMaximum" => true } ],
      # for string
      "minLength" => [ { "minLength" =>  10 }, { "minLength" =>  20 }, { "minLength" => 20 } ],
      "maxLength" => [ { "maxLength" =>  10 }, { "maxLength" =>  20 }, { "maxLength" => 10 } ],
      #"pattern"   => [ { "pattern" => "/hoge/" }, { "pattern" => "/fuga/" }, { "pattern" => "/^(?=.*hoge)(?=.*fuga)/" },  { "pattern" => "/^(?=.*fuga)(?=.*hoge)/" }],
      # for array
      "items_array" => [
        { "items" => [ { "minimum" => 3 }, { "maximum" => 3 } ] },
        { "items" => [ { "minimum" => 5 }, { "maximum" => 5 }, { "type" => ["string"] }] },
        { "items" => [ { "minimum" => 5 }, { "maximum" => 3 }, { "type" => ["string"] }] },
      ],
      "minItems"    => [ { "minItems" =>  10 }, { "minItems" =>  20 }, { "minItems" => 20 } ],
      "maxItems"    => [ { "maxItems" =>  10 }, { "maxItems" =>  20 }, { "maxItems" => 10 } ],
      "uniqueItems" => [ { "uniqueItems" => false }, { "uniqueItems" => true }, { "uniqueItems" => true } ],
      # for object
      "minProperties" => [ { "minProperties" =>  10 }, { "minProperties" =>  20 }, { "minProperties" => 20 } ],
      "maxProperties" => [ { "maxProperties" =>  10 }, { "maxProperties" =>  20 }, { "maxProperties" => 10 } ],
      "required"      => [
        { "properties" => { "a" => {}, "b" => {}, "c" => {} }, "required" => %w[ a b ] },
        { "properties" => { "a" => {}, "b" => {}, "c" => {} }, "required" => %w[ b c ] },
        { "properties" => { "a" => {}, "b" => {}, "c" => {} }, "required" => %w[ a b c ] },
        { "properties" => { "a" => {}, "b" => {}, "c" => {} }, "required" => %w[ b c a ] }
      ],
      "properties" => [
        { "properties" => { "a" => {}, "b" => { "minimum" => 10 } } },
        { "properties" => {            "b" => { "minimum" => 20 }, "c" => {} } },
        { "properties" => { "a" => {}, "b" => { "minimum" => 20 }, "c" => {} } },
      ],
      # for any
      "enum" => [ { "enum" => %w[ a b ] }, { "enum" => %w[ b c ] }, { "enum" => %w[ b ] } ],
      "type" => [ { "type" => "string" }, { "type" => [ "integer", "string" ] }, { "type" => [ "string" ] } ],
      "allOf" => [
        { "allOf" => [ { "minimum" => 10 } ] },
        { "allOf" => [ { "minimum" => 15, "maximum" => 20 } ] },
        { "allOf" => [ { "minimum" => 15, "maximum" => 20 } ] },
      ],
      "anyOf" => [
        { "anyOf" => [ { "minimum" => 10 }, { "maximum" => 20 } ] },
        { "anyOf" => [ { "maximum" => 20 } ] },
        { "anyOf" => [ { "maximum" => 20 } ] },
      ],
      "oneOf" => [
        { "oneOf" => [ { "minimum" => 20 }, { "maximum" => 10 } ] },
        { "oneOf" => [ { "maximum" => 10 } ] },
        { "oneOf" => [ { "maximum" => 10 } ] },
      ],
    }

    tests.each do |name, (a, b, answer, answer2)|
      a_schema      = ::JsonSchema.parse!(a)
      b_schema      = ::JsonSchema.parse!(b)
      target_schema = ::JsonSchema.parse!("allOf" => [ a, b ])

      context "#{name} test" do
        it "works" do
          expect(described_class.take_logical_and_of_schema(a_schema, b_schema)).to be_a_schema(answer)
          expect(described_class.take_logical_and_of_schema(b_schema, a_schema)).to be_a_schema(answer2 || answer)
        end

        it "is valid for all_of schema" do # test of test
          schema = ::JsonSchema.parse!(complete_schema(answer))
          expect(::JsonSchema::Faker.new(schema).generate).to be_valid_for(target_schema)
        end
      end
    end
  end
end
