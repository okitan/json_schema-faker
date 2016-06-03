module JsonSchema::Faker::Strategy
  class Simple
    def call(schema, hint: nil, position:)
      ::JsonSchema::Faker::Configuration.logger.debug "current position: #{position}" if ::JsonSchema::Faker::Configuration.logger

      raise "here comes nil for schema at #{position}" unless schema

      # merge one_of/any_of/all_of
      ::JsonSchema::Faker::Configuration.logger.debug schema.inspect_schema if ::JsonSchema::Faker::Configuration.logger
      schema = compact_schema(schema)

      return schema.default if schema.default

      if schema.not
        hint ||= {}
        # too difficult
        # TODO: support one_of/any_of/all_of
        hint[:not_have_keys] = schema.not.required if schema.not.required
        hint[:not_be_values] = schema.not.enum     if schema.not.enum
      end

      # http://json-schema.org/latest/json-schema-validation.html#anchor75
      if schema.enum
        generate_by_enum(schema, hint: hint, position: position)
      elsif !schema.type.empty?
        generate_by_type(schema, position: position)
      else # consider as object
        generate_for_object(schema, hint: hint, position: position)
      end
    end
    alias_method :generate, :call

    def generate_for_object(schema, hint: nil, position:)
      # http://json-schema.org/latest/json-schema-validation.html#anchor53
      if schema.required
        keys   = schema.required
        required_length = schema.min_properties || keys.length

        object = keys.each.with_object({}) do |key, hash|
          hash[key] = generate(schema.properties[key], hint: hint, position: "#{position}/#{key}") # TODO: pass hint
        end
      else
        required_length = schema.min_properties || schema.max_properties || 0

        keys = (schema.properties || {}).keys
        keys -= (hint[:not_have_keys] || []) if hint

        object = keys.first(required_length).each.with_object({}) do |key, hash|
          hash[key] = generate(schema.properties[key], hint: hint, position: "#{position}/#{key}") # TODO: pass hint
        end
      end

      # if length is not enough
      if schema.additional_properties === false
        (required_length - object.keys.length).times.each.with_object(object) do |i, hash|
          if schema.pattern_properties.empty?
            key = (schema.properties.keys - object.keys).first
            hash[key] = generate(schema.properties[key], hint: hint, position: "#{position}/#{key}")
          else
            name = ::Pxeger.new(schema.pattern_properties.keys.first).generate
            hash[name] = generate(schema.pattern_properties.values.first, hint: hint, position: "#{position}/#{name}")
          end
        end
      else
        # FIXME: key confilct with properties
        (required_length - object.keys.length).times.each.with_object(object) do |i, hash|
          hash[i.to_s] = i
        end
      end

      # consider dependency
      depended_keys = object.keys & schema.dependencies.keys

      # FIXME: circular dependency is not supported
      depended_keys.each.with_object(object) do |key, hash|
        dependency = schema.dependencies[key]

        if dependency.is_a?(::JsonSchema::Schema)
          # too difficult we just merge
          hash.update(generate(schema.dependencies[key], hint: nil, position: "#{position}/dependencies/#{key}"))
        else
          dependency.each do |additional_key|
            object[additional_key] = generate(schema.properties[additional_key], hint: hint, position: "#{position}/dependencies/#{key}/#{additional_key}") unless object.has_key?(additional_key)
          end
        end
      end
    end

    def generate_by_enum(schema, hint: nil, position:)
      black_list = (hint ? hint[:not_be_values] : nil)

      if ::JsonSchema::Faker::Configuration.logger
        ::JsonSchema::Faker::Configuration.logger.info "generate by enum at #{position}"
        ::JsonSchema::Faker::Configuration.logger.debug schema.inspect_schema
        ::JsonSchema::Faker::Configuration.logger.debug "black list: #{black_list}" if black_list
      end

      if black_list
        (schema.enum - black_list).first
      else
        schema.enum.first
      end
    end

    def generate_by_type(schema, hint: nil, position:)
      if ::JsonSchema::Faker::Configuration.logger
        ::JsonSchema::Faker::Configuration.logger.info "generate by type at #{position}"
        ::JsonSchema::Faker::Configuration.logger.debug schema.inspect_schema
      end

      # http://json-schema.org/latest/json-schema-core.html#anchor8
      # TODO: use include? than first
      case schema.type.first
      when "array"
        generate_for_array(schema, hint: hint, position: position)
      when "boolean"
        true
      when "integer", "number"
        generate_for_number(schema, hint: hint)
      when "null"
        nil
      when "object"
        # here comes object without properties
        generate_for_object(schema, hint: hint, position: position)
      when "string"
        generate_for_string(schema, hint: hint)
      else
        raise "unknown type for #{schema.inspect_schema}"
      end
    end

    def generate_for_array(schema, hint: nil, position:)
      # http://json-schema.org/latest/json-schema-validation.html#anchor36
      # additionalItems items maxItems minItems uniqueItems
      length = schema.min_items || 0

      if schema.items.nil?
        length.times.map.with_index {|i| i }
      else
        if schema.items.is_a?(Array)
          items = schema.items.map.with_index {|e, i| generate(e, hint: hint, position: "#{position}/items[#{i}]") }

          items + (length - items.size).map.with_index {|i| schema.additional_items === false ? i : generate(schema.additional_items, hint: hint, position: "#{position}/additional_items[#{i}]") }
        else
          length.times.map.with_index {|i| generate(schema.items, hint: hint, position: "#{position}/items[#{i}]") }
        end
      end
    end

    def generate_for_number(schema, hint: nil)
      # http://json-schema.org/latest/json-schema-validation.html#anchor13
      # TODO: use hint[:not_be_values]
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
      # TODO: use hint[:not_be_values]
      # TODO: support format
      if schema.pattern
        ::Pxeger.new(schema.pattern).generate
      else
        length = schema.min_length || 0
        "a" * length
      end
    end

    def compact_schema(schema)
      return schema if schema.one_of.empty? && schema.any_of.empty? && schema.all_of.empty?

      ::JsonSchema::Faker::Configuration.logger.info "start to compact" if ::JsonSchema::Faker::Configuration.logger

      merged_schema = ::JsonSchema::Schema.new
      merged_schema.copy_from(schema)
      merged_schema.one_of = []
      merged_schema.any_of = []
      merged_schema.all_of = []

      merge_schema!(merged_schema, compact_schema(schema.one_of.first)) unless schema.one_of.empty?
      merge_schema!(merged_schema, compact_schema(schema.any_of.first)) unless schema.any_of.empty?

      unless schema.all_of.empty?
        all_of = schema.all_of.inject {|a, b| merge_schema!(compact_schema(a), compact_schema(b)) }

        merge_schema!(merged_schema, all_of)
      end

      ::JsonSchema::Faker::Configuration.logger.debug merged_schema.inspect_schema if ::JsonSchema::Faker::Configuration.logger

      merged_schema
    end

    def merge_schema!(a, b)
      if ::JsonSchema::Faker::Configuration.logger
        ::JsonSchema::Faker::Configuration.logger.info "start to merge"
        ::JsonSchema::Faker::Configuration.logger.debug a.inspect_schema
        ::JsonSchema::Faker::Configuration.logger.debug b.inspect_schema
      end
      # attr not supported now
      # any_of:     too difficult / but actually no merge after comact_schema
      # enum/items: TODO: just get and of array
      # not:        too difficult (if `not` is not wrapped by all_of wrap it?)
      # multiple_of TODO: least common multiple
      # pattern:    too difficult...
      # format      TODO: just override

      # array properties
      %i[ type one_of all_of ].each do |attr|
        a.__send__("#{attr}=", a.__send__(attr) + b.__send__(attr))
      end
      a.required = (a.required ? a.required + b.required : b.required) if b.required

      # object properties
      # XXX: key conflict
      %i[ properties pattern_properties dependencies ].each do |attr|
        a.__send__("#{attr}=", a.__send__(attr).merge(b.__send__(attr)))
      end

      # override to stronger validation
      %i[ additional_items additional_properties ].each do |attr|
        a.__send__("#{attr}=", false) unless a.__send__(attr) && b.__send__(attr)
      end
      %i[ min_exclusive max_exclusive unique_items ].each do |attr|
        a.__send__("#{attr}=", a.__send__(attr) & b.__send__(attr))
      end
      %i[ min min_length min_properties ].each do |attr|
        if b.__send__(attr)
          if a.__send__(attr)
            a.__send__("#{attr}=", b.__send__(attr)) if b.__send__(attr) < a.__send__(attr)
          else
            a.__send__("#{attr}=", b.__send__(attr))
          end
        end
      end
      %i[ max max_length max_properties ].each do |attr|
        if b.__send__(attr)
          if a.__send__(attr)
            a.__send__("#{attr}=", b.__send__(attr)) if b.__send__(attr) > a.__send__(attr)
          else
            a.__send__("#{attr}=", b.__send__(attr))
          end
        end
      end

      ::JsonSchema::Faker::Configuration.logger.debug a.inspect_schema if ::JsonSchema::Faker::Configuration.logger

      a
    end
  end
end
