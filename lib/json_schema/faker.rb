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
      elsif !schema.any_of.empty?
      elsif !schema.all_of.empty?
      elsif !schema.properties.empty?
        generate_properties(schema, hint: hint, position: position)
      elsif schema.enum
      elsif schema.type
        generate_by_type(schema, position: position)
      elsif schema.not
      else
        {} # consider as "type": "object"
      end
    end

    def generate_properties(schema, hint: nil, position:)
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
        # http://json-schema.org/latest/json-schema-validation.html#anchor13
        # TODO: multiple_of, exclusive_max, exclusive_min
        min = schema.min || 0
        max = schema.max || min

        max
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
