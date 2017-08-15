require "json_schema/faker/util"

module JsonSchema::Faker::Strategy
  class Simple
    include ::JsonSchema::Faker::Util

    class << self
      def formats
        @formats ||= {}
      end
    end

    def call(schema, hint: nil, position:)
      if ::JsonSchema::Faker::Configuration.logger
        ::JsonSchema::Faker::Configuration.logger.debug "current position: #{position}"
        ::JsonSchema::Faker::Configuration.logger.debug "current hint:     #{hint.inspect}"
      end

      raise "here comes nil for schema at #{position}" unless schema

      # merge one_of/any_of/all_of
      ::JsonSchema::Faker::Configuration.logger.debug schema.inspect_schema if ::JsonSchema::Faker::Configuration.logger
      schema = compact_schema(schema, position: position)

      return schema.default if schema.default && schema.validate(schema.default).first
      return self.class.formats[schema.format].call(schema, hint: hint, position: position) if self.class.formats.has_key?(schema.format)

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
      if depended_keys.empty?
        object
      elsif depended_keys.all? {|key| schema.dependencies[key].is_a?(Array) }
        # FIXME: circular dependency is not supported
        depended_keys.each.with_object(object) do |key, hash|
          schema.dependencies[key].each do |additional_key|
            hash[additional_key] = generate(schema.properties[additional_key], hint: hint, position: "#{position}/dependencies/#{key}/#{additional_key}") unless object.has_key?(additional_key)
          end
        end
      else
        ::JsonSchema::Faker::Configuration.logger.info "generate again because of dependended keys exists: #{depended_keys}" if ::JsonSchema::Faker::Configuration.logger

        merged_schema = ::JsonSchema::Schema.new.tap {|s| s.copy_from(schema) }
        depended_keys.each do |key|
          dependency = schema.dependencies[key]
          if dependency.is_a?(::JsonSchema::Schema)
            merged_schema = compact_schema(take_logical_and_of_schema(merged_schema, dependency), position: position)
          else
            merged_schema.required = (merged_schema.required + dependency).uniq
          end
        end
        merged_schema.dependencies = nil # XXX: recursive dependency will fail
        generate_for_object(merged_schema, hint: hint, position: position)
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
        generate_for_number(schema, hint: hint, position: position)
      when "null"
        nil
      when "object", nil
        # here comes object without properties
        generate_for_object(schema, hint: hint, position: position)
      when "string"
        generate_for_string(schema, hint: hint, position: position)
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

          items + (length - items.size).times.map.with_index {|i| schema.additional_items === false ? i : generate(schema.additional_items, hint: hint, position: "#{position}/additional_items[#{i}]") }
        else
          length.times.map.with_index {|i| generate(schema.items, hint: hint, position: "#{position}/items[#{i}]") }
        end
      end
    end

    def generate_for_number(schema, hint: nil, position:)
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

    def generate_for_string(schema, hint: nil, position:)
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

    # TODO: compacting all_of and one_of/any_of at once will not work
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

      unless schema.all_of.empty?
        ::JsonSchema::Faker::Configuration.logger.info "compact all_of" if ::JsonSchema::Faker::Configuration.logger

        all_of = schema.all_of.each.with_index.inject(nil) do |(a, _), (b, i)|
          if a
            take_logical_and_of_schema(a, b, a_position: "#{position}/all_of", b_position: "#{position}/all_of[#{i+1}]")
          else
            b
          end
        end

        unless schema.one_of.empty? && schema.any_of.empty?
          ::JsonSchema::Faker::Configuration.logger.info "find from one_of and any_of which satiffy all_of" if ::JsonSchema::Faker::Configuration.logger
          one_of_candidate = schema.one_of.find do |s|
            s2 = take_logical_and_of_schema(s, all_of)
            compare_schema(s, s2) # FIXME: check s2 > s
          end

          any_of_candidate = schema.any_of.find do |s|
            s2 = take_logical_and_of_schema(s, all_of)
            compare_schema(s, s2) # FIXME: check s2 > s
          end

          unless one_of_candidate || any_of_candidate
            ::JsonSchema::Faker::Configuration.logger.error "failed to find condition which satfisfy all_of in one_of and any_of" if ::JsonSchema::Faker::Configuration.logger
            merged_schema = take_logical_and_of_schema(merged_schema, all_of, a_position: position, b_position: "#{position}/all_of")
          else
            merged_schema = take_logical_and_of_schema(merged_schema, one_of_candidate, a_position: position, b_position: "#{position}/one_of") if one_of_candidate
            merged_schema = take_logical_and_of_schema(merged_schema, any_of_candidate, a_position: position, b_position: "#{position}/any_of") if any_of_candidate
          end
        else
          merged_schema = take_logical_and_of_schema(merged_schema, all_of, a_position: position, b_position: "#{position}/all_of")
        end
      else
        unless schema.one_of.empty?
          ::JsonSchema::Faker::Configuration.logger.info "compact one_of" if ::JsonSchema::Faker::Configuration.logger
          merged_schema = take_logical_and_of_schema(merged_schema, schema.one_of.first, a_position: position, b_position: "#{position}/one_of[0]")
        end

        unless schema.any_of.empty?
          ::JsonSchema::Faker::Configuration.logger.info "compact any_of" if ::JsonSchema::Faker::Configuration.logger
          merged_schema = take_logical_and_of_schema(merged_schema, schema.any_of.first, a_position: position, b_position: "#{position}/any_of[0]")
        end
      end

      # compact recursively
      merged_schema = compact_schema(merged_schema, position: position)

      ::JsonSchema::Faker::Configuration.logger.debug "compacted: #{merged_schema.inspect_schema}" if ::JsonSchema::Faker::Configuration.logger

      merged_schema
    end
  end
end
