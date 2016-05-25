require "json_schema"

require "pxeger"

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
      # TODO: support pattern properties
      # http://json-schema.org/latest/json-schema-validation.html#anchor75
      # Notes:
      # one_of, any_of, all_of, properties and type is given default and never be nil
      if    !schema.one_of.empty?
        generate_for_one_of(schema, hint: hint, position: position)
      elsif !schema.any_of.empty?
        generate_for_any_of(schema, hint: hint, position: position)
      elsif !schema.all_of.empty?
        generate_for_all_of(schema, hint: hint, position: position)
      elsif !schema.properties.empty?
        generate_for_properties(schema, hint: hint, position: position)
      elsif schema.enum
        generate_by_enum(schema, hint: hint, position: position)
      elsif !schema.type.empty?
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

    def generate_by_enum(schema, hint: nil, position:)
      if Configuration.logger
        Configuration.logger.info "generate by enum at #{position}"
        Configuration.logger.debug schema.inspect_schema
      end
      schema.enum.first
    end

    def generate_by_type(schema, hint: nil, position:)
      if Configuration.logger
        Configuration.logger.info "generate by type at #{position}"
        Configuration.logger.debug schema.inspect_schema
      end

      # http://json-schema.org/latest/json-schema-core.html#anchor8
      case schema.type.first
      when "array"
        generate_for_array(schema, hint: nil, position: position)
      when "boolean"
        true
      when "integer", "number"
        generate_for_number(schema, hint: nil)
      when "null"
        nil
      when "object"
      when "string"
        generate_for_string(schema, hint: hint)
      else
        raise "unknown type for #{schema.inspect_schema}"
      end
    end

    def generate_for_array(schema, hint: nil, position:)
      #binding.pry
      # http://json-schema.org/latest/json-schema-validation.html#anchor36
      # additionalItems items maxItems minItems uniqueItems
      length = schema.min_items || 0

      # if "items" is not present, or its value is an object, validation of the instance always succeeds, regardless of the value of "additionalItems";
      # if the value of "additionalItems" is boolean value true or an object, validation of the instance always succeeds;
      item = if (schema.items.nil? || schema.items.is_a?(JsonSchema::Schema)) || ( schema.additional_items === true || schema.additional_items.is_a?(JsonSchema::Schema))
        length.times.map.with_index {|i| i }
      else # in case schema.items is array and schema.additional_items is true
        # if the value of "additionalItems" is boolean value false and the value of "items" is an array
        # the instance is valid if its size is less than, or equal to, the size of "items".
        raise "#{position}: item length(#{schema.items.length} is shorter than minItems(#{schema.min_items}))" unless schema.items.length <= length

        # TODO: consider unique items
        length.times.map.with_index {|i| _generate(schema.items[i], position: position + "[#{i}]") }
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

    def generate_for_string(schema, hint: nil)
      # http://json-schema.org/latest/json-schema-validation.html#anchor25
      if schema.pattern
        Pxeger.new(schema.pattern).generate
      else
        length = schema.min_length || 0
        "a" * length
      end
    end
  end
end
