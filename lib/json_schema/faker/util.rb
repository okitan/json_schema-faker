require "json_schema/faker"

class JsonSchema::Faker
  module Util
    # umhhh maybe we don't need this...
    def compare_schema(a, b)
      if a.is_a?(::JsonSchema::Schema) && b.is_a?(::JsonSchema::Schema)
        a.data == b.data
      else
        a == b
      end
    end

    def take_unique_items(a, b)
      a.select do |ai|
        b.any? {|bi| compare_schema(ai, bi)}
      end
    end

    def take_logical_and_of_schema(a, b, a_position: nil, b_position: nil)
      return a || b if a.nil? || b.nil?

      # deep copy and modify it
      a = Marshal.load(Marshal.dump(a))

      # for numeric
      if a.multiple_of && b.multiple_of
        # TODO: multipleOf it seems easy
        ::JsonSchema::Faker::Configuration.logger.warn "not support merging multipleOf" if ::JsonSchema::Faker::Configuration.logger
      end

      # maximum minimum exclusiveMinimum exclusiveMinimum
      if b.max
        if !a.max || a.max > b.max
          a.max = b.max
        end
        a.max_exclusive = b.max_exclusive if b.max_exclusive
      end
      if b.min
        if !a.min || a.min < b.min
          a.min = b.min
        end
        a.min_exclusive = b.min_exclusive if b.min_exclusive
      end

      # for string
      # maxLength minLength
      if b.max_length
        if !a.max_length || a.max_length > b.max_length
          a.max_length = b.max_length
        end
      end
      if b.min_length
        if !a.min_length || a.min_length < b.min_length
          a.min_length = b.min_length
        end
      end
      # pattern
      if a.pattern && b.pattern
        # TODO: pexeger does not support generated one
        ::JsonSchema::Faker::Configuration.logger.warn "not support merging pattern" if ::JsonSchema::Faker::Configuration.logger
      end
      #if b.pattern
      #  a.pattern = (a.pattern ? "/^(?=.*#{a.pattern.inspect.gsub("/\\/", "").gsub("\\//", "")})(?=.*#{b.pattern.inspect.gsub("/\\/", "").gsub("\\//", "")})/" : b.pattern)
      #end

      # for array
      # items and aditionalItems
      if b.items
        if a.items
          if a.items.is_a?(Array) && b.items.is_a?(Array)
            [ a.items.size, b.items.size ].max.times do |i|
              ai, bi = a.items[i], b.items[i]
              if ai && bi
                a.items[i] = take_logical_and_of_schema(ai, bi)
              else
                # XXX: consider aditionalItems
                a.items[i] = ai || bi
              end
            end
          elsif a.items.is_a?(::JsonSchema::Schema) && b.items.is_a?(::JsonSchema::Schema)
            a.items = take_logical_and_of_schema!(a.items b.items)
          end
        else
          a.items = b.items
        end
      end
      if a.additional_items === false || b.additional_items === false
        a.additonal_items = false
      else
        if b.additional_items.is_a?(::JsonSchema::Schema)
          if a.additional_items.is_a?(::JsonSchem::Schema)
            ::JsonSchema::Faker::Configuration.logger.warn "not support merging additionalItems" if ::JsonSchema::Faker::Configuration.logger
          else
            a.additional_items = b.additional_items
          end
        end
      end
      # maxItems, minItems
      if b.max_items
        if !a.max_items || a.max_items > b.max_items
          a.max_items = b.max_items
        end
      end
      if b.min_items
        if !a.min_items || a.min_items < b.min_items
          a.min_items = b.min_items
        end
      end
      # uniqueItems
      if a.unique_items || b.unique_items
        a.unique_items = true
      end

      # for object
      # maxProperties, minProperties
      if b.max_properties
        if !a.max_properties || a.max_properties > b.max_properties
          a.max_properties = b.max_properties
        end
      end
      if b.min_properties
        if !a.min_properties || a.min_properties < b.min_properties
          a.min_properties = b.min_properties
        end
      end
      # required
      if b.required
        a.required = a.required ? (a.required + b.required).uniq : b.required
      end
      # properties
      if !b.properties.empty?
        ( a.properties.keys + b.properties.keys ).uniq.each do |key|
          a.properties[key] = take_logical_and_of_schema(a.properties[key], b.properties[key])
        end
      end
      # additionalProperties, patternProperties, dependencies
      if a.additional_properties === false || b.additional_properties === false
        a.additional_properties = false
      else
        if b.additional_properties.is_a?(::JsonSchema::Schema)
          if a.additional_properties.is_a?(::JsonSchem::Schema)
            ::JsonSchema::Faker::Configuration.logger.warn "not support merging additionalProperties" if ::JsonSchema::Faker::Configuration.logger
          else
            a.additional_properties = b.additional_properties
          end
        end
      end
      if !b.pattern_properties.empty?
        if !a.pattern_properties.empty?
          ::JsonSchema::Faker::Configuration.logger.warn "not support merging patternProperties" if ::JsonSchema::Faker::Configuration.logger
        else
          a.pattern_properties = b.pattern_properties
        end
      end
      if !b.dependencies.empty?
        if !a.dependencies.empty?
          ::JsonSchema::Faker::Configuration.logger.warn "not support merging dependencies" if ::JsonSchema::Faker::Configuration.logger
        else
          a.dependencies = b.dependencies
        end
      end
      # for any
      # enum
      if b.enum
        if a.enum
          a.enum = a.enum & b.enum
        else
          a.enum = b.enum
        end
      end
      # type
      if !b.type.empty?
        if !a.type.empty?
          a.type = a.type & b.type
        else
          a.type = b.type
        end
      end
      # allOf
      if !b.all_of.empty?
        if !a.all_of.empty?
          a.all_of = [
            [ *a.all_of, *b.all_of ].inject(nil) {|res, c| res ? take_logical_and_of_schema(res, c) : c }
          ]
        else
          a.all_of = b.all_of
        end
      end
      # anyOf
      if !b.any_of.empty?
        if !a.any_of.empty?
          # XXX: it is difficult to find logically and of any_of
          # like "anyOf": { "minimum": 5 }, { "multipleOf": 3 } and { "maximum": 6 }, { "multipleOf": 2 }
          a.any_of = take_unique_items(a.any_of, b.any_of)
        else
          a.any_of = b.any_of
        end
      end
      # oneOf
      if !b.one_of.empty?
        if !a.one_of.empty?
          # XXX: it is difficult to find logically and of one_of
          a.one_of = take_unique_items(a.one_of, b.one_of)
        else
          a.one_of = b.one_of
        end
      end
      # not
      if b.not
        if a.not
          ::JsonSchema::Faker::Configuration.logger.warn "not support merging not" if ::JsonSchema::Faker::Configuration.logger
        else
          a.not = b.not
        end
      end

      a
    end


    module_function *instance_methods
  end
end
