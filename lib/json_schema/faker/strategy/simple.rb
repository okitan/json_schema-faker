module JsonSchema::Faker::Strategy
  class Simple
    def call(schema, hint: nil, position:)
      if ::JsonSchema::Faker::Configuration.logger
        ::JsonSchema::Faker::Configuration.logger.debug "current position: #{position}"
        ::JsonSchema::Faker::Configuration.logger.debug "current hint:     #{hint.inspect}"
      end

      raise "here comes nil for schema at #{position}" unless schema

      # merge one_of/any_of/all_of
      ::JsonSchema::Faker::Configuration.logger.debug schema.inspect_schema if ::JsonSchema::Faker::Configuration.logger
      schema = compact_schema(schema, position: position)

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
      else
        generate_by_type(schema, hint: hint, position: position)
      end
    end
    alias_method :generate, :call

    def generate_for_object(schema, hint: nil, position:)
      # complete hint
      object = if hint && hint[:example] && hint[:example].is_a?(Hash)
        hint[:example].each.with_object({}) do |(key, value), hash|
          if value.is_a?(Hash)
            if schema.properties.has_key?(key)
              hash[key] =  generate(schema.properties[key], hint: { example: hint[:example][key] }, position: "#{position}/#{key}")
            else
              # TODO: support pattern properties
              hash[key] = value
            end
          else
            hash[key] = value
          end
        end
      else
        {}
      end

      # http://json-schema.org/latest/json-schema-validation.html#anchor53
      if schema.required
        keys   = schema.required
        required_length = schema.min_properties || keys.length

        (keys - object.keys).each.with_object(object) do |key, hash|
          hash[key] = generate(schema.properties[key], hint: hint, position: "#{position}/#{key}")
        end
      else
        required_length = schema.min_properties || schema.max_properties || 0

        keys = (schema.properties || {}).keys - object.keys
        keys -= hint[:not_have_keys] if hint && hint[:not_have_keys]

        keys.first(required_length).each.with_object(object) do |key, hash|
          hash[key] = generate(schema.properties[key], hint: hint, position: "#{position}/#{key}")
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
      list       = black_list ? schema.enum - black_list : schema.enum

      if ::JsonSchema::Faker::Configuration.logger
        ::JsonSchema::Faker::Configuration.logger.info "generate by enum at #{position}"
        ::JsonSchema::Faker::Configuration.logger.debug schema.inspect_schema
        ::JsonSchema::Faker::Configuration.logger.debug "black list: #{black_list}" if black_list
        ::JsonSchema::Faker::Configuration.logger.debug "list: #{list}"
      end

      return hint[:example] if hint && hint[:example] && hint[:example] && list.include?(hint[:example])

      list.first
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
        return hint[:example] if hint && hint[:example] && (hint[:example] === true || hint[:example] === false)

        true
      when "integer", "number"
        generate_for_number(schema, hint: hint)
      when "null"
        nil
      when "object", nil
        # here comes object without properties
        generate_for_object(schema, hint: hint, position: position)
      when "string"
        generate_for_string(schema, hint: hint)
      else
        raise "unknown type for #{schema.inspect_schema}"
      end
    end

    def generate_for_array(schema, hint: nil, position:)
      # completing each items is difficult
      return hint[:example] if hint && hint[:example] && hint[:example].is_a?(Array)

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
      return hint[:example] if hint && hint[:example] && hint[:example].is_a?(Numeric)

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
      return hint[:example] if hint && hint[:example] && hint[:example].is_a?(String)

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

    def compact_and_merge_schema(a, b, a_position:, b_position:)
      merge_schema!(
        compact_schema(a, position: a_position),
        compact_schema(b, position: b_position),
        a_position: a_position,
        b_position: b_position
      )
    end

    def compact_schema(schema, position:)
      return schema if schema.one_of.empty? && schema.any_of.empty? && schema.all_of.empty?

      if ::JsonSchema::Faker::Configuration.logger
        ::JsonSchema::Faker::Configuration.logger.info "start to compact at #{position}"
        ::JsonSchema::Faker::Configuration.logger.debug schema.inspect_schema
      end

      merged_schema = ::JsonSchema::Schema.new
      merged_schema.copy_from(schema)
      merged_schema.one_of = []
      merged_schema.any_of = []
      merged_schema.all_of = []

      unless schema.one_of.empty?
        ::JsonSchema::Faker::Configuration.logger.info "compact one_of" if ::JsonSchema::Faker::Configuration.logger
        compact_and_merge_schema(merged_schema, schema.one_of.first, a_position: position, b_position: "#{position}/one_of[0]")
      end

      unless schema.any_of.empty?
        ::JsonSchema::Faker::Configuration.logger.info "compact any_of" if ::JsonSchema::Faker::Configuration.logger
        compact_and_merge_schema(merged_schema, schema.any_of.first, a_position: position, b_position: "#{position}/any_of[0]")
      end

      unless schema.all_of.empty?
        ::JsonSchema::Faker::Configuration.logger.info "compact all_of" if ::JsonSchema::Faker::Configuration.logger
        all_of = ::JsonSchema::Schema.new
        all_of.copy_from(schema.all_of.first)

        all_of = schema.all_of[1..-1].each.with_index.inject(all_of) do |(a, _), (b, i)|
          compact_and_merge_schema(a, b, a_position: "#{position}/all_of", b_position: "#{position}/all_of[#{i+1}]")
        end

        merge_schema!(merged_schema, all_of, a_position: position, b_position: "#{position}/all_of")
      end

      ::JsonSchema::Faker::Configuration.logger.debug "compacted: #{merged_schema.inspect_schema}" if ::JsonSchema::Faker::Configuration.logger

      merged_schema
    end

    def merge_schema!(a, b, a_position:, b_position:)
      if ::JsonSchema::Faker::Configuration.logger
        ::JsonSchema::Faker::Configuration.logger.info "start to merge at #{a_position} with #{b_position}"
        ::JsonSchema::Faker::Configuration.logger.debug "a: #{a.inspect_schema}"
        ::JsonSchema::Faker::Configuration.logger.debug "b: #{b.inspect_schema}"
      end
      # attr not supported now
      # not:        too difficult (if `not` is not wrapped by all_of wrap it?)
      # multiple_of TODO: least common multiple
      # format      TODO: just override

      # array properties
      a.any_of = (a.any_of.empty? ? b.any_of : a.any_of) # XXX: actually impossible
      a.enum = (a.enum    ? (a.enum & b.enum) : b.enum) if b.enum

      %i[ type one_of all_of ].each do |attr|
        a.__send__("#{attr}=", a.__send__(attr) + b.__send__(attr))
      end
      a.required = (a.required ? (a.required + b.required).uniq : b.required) if b.required

      # object properties
      # XXX: key conflict
      %i[ properties pattern_properties dependencies ].each do |attr|
        a.__send__("#{attr}=", a.__send__(attr).merge(b.__send__(attr)))
      end

      # array of object
      if a.items && b.items
        if a.items.is_a?(Array) && b.items.is_a?(Array)
          # TODO: zip and merge it
        elsif a.items.is_a?(Array) && b.items.is_a?(::JsonSchema::Schema)
          a.items = a.items.map.with_index do |e, i|
            compact_and_merge_schema(e, b.items, a_position: "#{a_position}/items[#{i}]", b_position: "#{b_position}/items")
          end
        elsif a.items.is_a?(::JsonSchema::Schema) && a.items.is_a?(Array)
          a.items = b.items.map.with_index do |e, i|
            compact_and_merge_schema(a.items, e, a_position: "#{a_position}/items", b_position: "#{b_position}/items[#{i}]")
          end
        else
          compact_and_merge_schema(a.items, b.items, a_position: "#{a_position}/items", b_position: "#{b_position}/items")
        end
      else
        a.items ||= b.items
      end

      # override to stronger validation
      %i[ additional_items additional_properties ].each do |attr|
        a.__send__("#{attr}=", false) unless a.__send__(attr) && b.__send__(attr)
      end
      %i[ min_exclusive max_exclusive unique_items ].each do |attr|
        a.__send__("#{attr}=", a.__send__(attr) & b.__send__(attr))
      end
      %i[ min min_length min_properties min_items ].each do |attr|
        if b.__send__(attr)
          if a.__send__(attr)
            a.__send__("#{attr}=", b.__send__(attr)) if b.__send__(attr) < a.__send__(attr)
          else
            a.__send__("#{attr}=", b.__send__(attr))
          end
        end
      end
      %i[ max max_length max_properties max_items ].each do |attr|
        if b.__send__(attr)
          if a.__send__(attr)
            a.__send__("#{attr}=", b.__send__(attr)) if b.__send__(attr) > a.__send__(attr)
          else
            a.__send__("#{attr}=", b.__send__(attr))
          end
        end
      end
      a.pattern = (a.pattern && b.pattern) ? "(?:#{a.pattern})(?=#{b.pattern})" : (a.pattern || b.pattern)

      ::JsonSchema::Faker::Configuration.logger.debug "merged: #{a.inspect_schema}" if ::JsonSchema::Faker::Configuration.logger

      a
    end
  end
end
