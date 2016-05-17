require "json_schema"

module JsonSchema
  class Faker
    module Configuration
      attr_accessor :logger

      module_function :logger, :logger=
    end

    # TODO:
    # strategy to use for faker
    def initialize(schema, options = {})
      @schema  = schema

      @options = options
    end

    def generate(hint: nil)
      _generate(@schema, hint: nil, position: "")
    end

    protected
    def _generate(schema, hint: nil, position:)
      Configuration.logger.debug "current position: #{position}" if Configuration.logger

      # TODO: should support the combinations of them
      # http://json-schema.org/latest/json-schema-validation.html#anchor75
      if    !schema.one_of.empty?
        generate_for_one_of(schema, hint: hint, position: position)
      elsif !schema.any_of.empty?
        generate_for_any_of(schema, hint: hint, position: position)
      elsif !schema.all_of.empty?
        generate_for_all_of(schema, hint: hint, position: position)
      elsif !schema.properties.empty?
        generate_for_properties(schema, hint: hint, position: position)
      elsif schema.enum
      elsif schema.type
        generate_by_type(schema, position: position)
      elsif schema.not
      else
        {} # consider as "type": "object"
      end
    end

    def generate_for_one_of(schema, hint: nil, position:)
    end

    def generate_for_any_of(schema, hint: nil, position:)
    end

    def generate_for_all_of(schema, hint: nil, position:)
    end

    def generate_for_properties(schema, hint: nil, position:)
      schema.properties.each.with_object({}) do |(key, value), hash|
        hash[key] = _generate(value, hint: nil, position: "#{position}/#{key}") # TODO: pass hint
      end
    end

    def generate_by_type(schema, hint: nil, position:)
      if Configuration.logger
        Configuration.logger.info "generate type at #{position}"
        Configuration.logger.debug schema.inspect_schema
      end

      # http://json-schema.org/latest/json-schema-core.html#anchor8
      case schema.type.first
      when "array"
      when "boolean"
      when "integer", "number"
        generate_for_number(schema, hint: nil)
      when "null"
        nil
      when "object"
      when "string"
      else
        raise "unknown type for #{schema.inspect_schema}"
      end
    end

    def generate_for_number(schema, hint: nil)
      # http://json-schema.org/latest/json-schema-validation.html#anchor13
      min = schema.min
      max = schema.max

      if schema.multiple_of
        min = (min + schema.multiple_of - min % schema.multiple_of) if min
        max = (max - max % schema.multiple_of) if max
      end

      delta = schema.multiple_of ? schema.multiple_of : 1

      # TODO: more sophisticated caluculation
      min, max = [ (min || (max ? max - delta * 2 : 0)), (max || (min ? min + delta * 2 : 0)) ]

      # to get average of min and max can avoid exclusive*
      if schema.type.first == "integer"
        (min / delta + max / delta) / 2 * delta
      else
        (min + max) / 2.0
      end
    end
  end
end
