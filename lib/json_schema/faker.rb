require "json_schema"

module JsonSchema
  class Faker
    # TODO:
    # strategy to use for faker
    def initialize(schema, options = {})
      @schema  = schema

      @options = options
    end

    def generate(hint: nil)
      _generate(@schema, hint: nil)
    end

    protected
    def _generate(schema, hint: nil)
      # TODO: should support the combinations of them
      # http://json-schema.org/latest/json-schema-validation.html#anchor75
      if    !schema.one_of.empty?
      elsif !schema.any_of.empty?
      elsif !schema.all_of.empty?
      elsif !schema.properties.empty?
        generate_properties(schema, hint: hint)
      elsif schema.enum
      elsif schema.type
        generate_by_type(schema)
      elsif schema.not
      else
        {} # consider as "type": "object"
      end
    end

    def generate_properties(schema, hint: nil)
      schema.properties.each.with_object({}) do |(key, value), hash|
        hash[key] = _generate(value, hint: nil) # TODO: pass hint
      end
    end

    def generate_by_type(schema, hint: nil)
      # http://json-schema.org/latest/json-schema-core.html#anchor8
      case schema.type.first
      when "array"
      when "boolean"
      when "integer", "number"
        # http://json-schema.org/latest/json-schema-validation.html#anchor13
        0
      when "null"
        nil
      when "object"
      when "string"
      else
        raise "unknown type for #{schema.inspect_schema}"
      end
    end
  end
end
