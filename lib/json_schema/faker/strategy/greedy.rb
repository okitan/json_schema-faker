require "json_schema/faker/strategy/simple"

module JsonSchema::Faker::Strategy
  class Greedy < Simple
    def generate_for_object(schema, hint: nil, position:)
      # complete hint
      object = if hint && hint[:example] && hint[:example].is_a?(Hash)
        hint[:example].each.with_object({}) do |(key, value), hash|
          if value.is_a?(Hash)
            if schema.properties.has_key?(key)
              hash[key] = generate(schema.properties[key], hint: { example: hint[:example][key] }, position: "#{position}/#{key}")
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

      if hint && hint[:not_have_keys]
        candidates      = schema.properties.keys - object.keys - hint[:not_have_keys]
        required_length = schema.max_properties || [ (schema.properties.keys - hint[:not_have_keys]).size, (schema.min_properties || 0) ].max
      else
        candidates      = schema.properties.keys - object.keys
        required_length = schema.max_properties || [ schema.properties.keys.size, (schema.min_properties || 0) ].max
      end

      # http://json-schema.org/latest/json-schema-validation.html#anchor53
      # TODO: candidates.shift(required_length)
      candidates.first(required_length).each.with_object(object) do |key, hash|
        hash[key] = generate(schema.properties[key], hint: hint, position: "#{position}/#{key}")
      end
      candidates = candidates - object.keys

      # if length is not enough
      if schema.additional_properties === false
        (required_length - object.keys.length).times.each.with_object(object) do |i, hash|
          if schema.pattern_properties.empty?
            key = candidates.pop
            hash[key] = generate(schema.properties[key], hint: hint, position: "#{position}/#{key}") if key
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
            hash[additional_key] = generate(schema.properties[additional_key], hint: hint, position: "#{position}/dependencies/#{key}/#{additional_key}") unless object.has_key?(additional_key)
          end
        end
      end
    end
  end
end
