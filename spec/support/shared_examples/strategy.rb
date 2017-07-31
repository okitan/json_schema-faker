RSpec.shared_examples "strategy" do
  context "against json_schema-faker standard test set" do
    it_behaves_like "generating data from properties which passes validation" do
      let(:properties) do
        {
          # array
          "array"                   => { "type" => "array" },
          "array_without_items"     => { "type" => "array", "minItems" => 1 },
          "array_with_length"       => { "type" => "array", "minItems" => 1 },
          "array_everything_ok"     => { "type" => "array", "minItems" => 1, "items" => [ {} ], "additionalItems" => true },
          "array_everything_ok2"    => { "type" => "array", "minItems" => 1, "items" => [ {} ], "additionalItems" => {} },
          "array_everything_ok3"    => { "type" => "array", "minItems" => 1,                    "additionalItems" => false },
          "array_with_object_items" => { "type" => "array", "minItems" => 1, "items" => {},     "additionalItems" => false },
          "array_with_items"        => { "type" => "array", "minItems" => 1, "items" => [ {} ], "additionalItems" => false },
          "array_with_items2"       => { "type" => "array", "minItems" => 2, "items" => [ { "enum" => [ 1 ] }, { "type" => "string" } ], "additionalItems" => false },
          # boolean
          "boolean"              => { "type" => "boolean" },
          # integer
          "integer"              => { "type" => "integer" },
          "integer_with_minimum" => { "type" => "integer", "minimum" => 10 },
          "integer_with_maximum" => { "type" => "integer", "maximum" => -10 },
          "integer_with_minmax"  => { "type" => "integer", "minimum" => 2, "maximum" => 3 },
          "multiple"              => { "type" => "integer", "multipleOf" => 3 },
          "multiple_with_minimum" => { "type" => "integer", "multipleOf" => 3, "minimum" => 2 },
          "multiple_with_maximum" => { "type" => "integer", "multipleOf" => 3, "minimum" => -4 },
          "multiple_with_minmax"  => { "type" => "integer", "multipleOf" => 3, "minimum" => 2, "maximum" => 4 },
          # TODO: add test about exclusiveMinimum, exclusiveMaximum
          # number
          "number"              => { "type" => "number" },
          "number_with_minmax"  => { "type" => "number", "minimum" => 2, "maximum" => 3, "exclusiveMinimum" => true, "exclusiveMaximum" => true },
          # null
          "null"                => { "type" => "null" },
          # object (object with properties is done in other context
          "object"              => { "type" => "object" },
          "empty_object"        => {},
          # string
          "string"              => { "type" => "string" },
          "string_with_min"     => { "type" => "string", "minLength" => 1 },
          "string_with_max"     => { "type" => "string", "maxLength" => 255 },
          "string_with_minmax"  => { "type" => "string", "minLength" => 254, "maxLength" => 255 },
          "string_with_pattern" => { "type" => "string", "pattern" => "^\w+$" },
          # oneOf
          "one_of" => { "oneOf" => [ { "type" => "string" } ] },
          # anyOf
          "any_of" => { "anyOf" => [ { "type" => "string" } ] },
          # allOf
          "all_of" => { "allOf" => [
            { "properties" => { "a" => { "enum" => [ "a", "b" ] }, "b" => { "enum" => [ "b" ] } }, "required" => %w[ a ] },
            { "required" => %w[ b ] }, # merge required
            { "properties" => { "c" => { "enum" => [ "c" ] } }, "required" => %w[ c ] }, # additional property
          ]},
          "all_of_min" => { "allOf" => [
            { "type" => "integer" },
            { "minimum" => 10000 },
          ]},
          "all_of_max" => { "allOf" => [
            { "type" => "integer" },
            { "maximum" => -10000 },
          ]},
          # not
          "not_be_values" => { "enum" => [ "a", "b" ], "not" => { "enum" => [ "a" ] } },
        }
      end
    end

    context "object" do
      it_behaves_like "generating data from properties which passes validation" do
        let(:common_properties) do
          { "a" => { "enum" => [ "a" ] }, "b" => { "enum" => [ "b" ] } }
        end

        let(:properties) do
          {
            "with_min"                    => { "properties" => common_properties,                        "minProperties" => 1 },
            "with_min_large"              => { "properties" => common_properties,                        "minProperties" => 3 },
            "with_required"               => { "properties" => common_properties, "required" => %w[ a ] },
            "required_and_no_additional"  => { "properties" => common_properties, "required" => %w[ a ], "minProperties" => 2, "additionalProperties" => false },
            "min_is_larger_than_required" => { "properties" => common_properties, "required" => %w[ a ], "minProperties" => 3 },
            "pattern_properties"          => { "patternProperties" => { "\\d+" => { "type" => "integer" } }, "minProperties" => 1, "additionalProperties" => false },
            "with_required_and_pattern"   => { "properties" => common_properties, "required" => %w[ a ], "minProperties" => 3,
                                               "patternProperties" => { "\\d+" => { "type" => "integer" } }, "additionalProperties" => false },
            "properties_with_pattern"     => { "properties" => common_properties,                        "minProperties" => 2,
                                               "patternProperties" => { "\\d+" => { "type" => "integer" } }, "additionalProperties" => false },
            "with_schema_dependency"      => { "properties" => common_properties, "required" => %w[ a ],
                                               "dependencies" => { "a" => { "properties" => { "c" => { "enum" => [ "c" ] } }, "required" => %w[ c ] } } },
            "with_property_dependency"    => { "properties" => common_properties, "required" => %w[ a ],
                                               "dependencies" => { "a" => [ "b" ] } },
            "not" => { "properties" => common_properties, "minProperties" => 1, "additionalProperties" => false ,"not" => { "required" => [ "a" ] } },
          }
        end
      end
    end
  end

  context "against json-schema-org test suite schema" do
    def self.skip?(file, num)
      return "treat the rest of one_of as not is not supported" if file == "suite/tests/draft4/oneOf.json" && num == 1
      return "seems difficult"                                  if file == "suite/tests/draft4/not.json"   && num == 2

      false
    end

    def complete_schema_from_filename(schema, file)
      schema
    end

    Dir["suite/tests/draft4/**/*.json"].sort.each do |file|
      next if file == "suite/tests/draft4/definitions.json" # json_schema does not support resolve ref over http
      next if file == "suite/tests/draft4/ref.json"         # they should be root schema and when I do it, faker will always return {}
      next if file == "suite/tests/draft4/refRemote.json"   # json shema does not support resolve ref over http

      fcontext "from suite #{file}" do
        tests = JSON.parse(File.read(file))

        tests.each.with_index do |test, i|
          context "[#{i}] (#{test["description"]})", test: "#{file}[#{i}]", skip: skip?(file, i) do
            it_behaves_like "generating data from properties which passes validation" do
              let(:properties) do
                { "#{file}[#{i}]" => complete_schema_from_filename(test["schema"], file) }
              end
            end
          end
        end
      end
    end
  end
end
