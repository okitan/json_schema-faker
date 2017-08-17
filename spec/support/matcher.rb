require "active_support/core_ext/string/inflections"

RSpec::Matchers.define :be_valid_for do |schema|
  match do |actual|
    schema.validate(actual).first
  end

  failure_message do |actual|
    errors = schema.validate(actual).last

    "expected that #{actual} would be valid for #{schema.inspect_schema}:\n  " + errors.join("\n  ")
  end
end

RSpec::Matchers.define :be_a_schema do |hash|
  def normalize_pointer(pointer)
    # https://github.com/brandur/json_schema/issues/87
    pointer.gsub("minimum", "min")\
           .gsub("maximum", "max")
  end

  def get_value_of_schema(schema, key)
    case key
    when "minimum"
      schema.min
    when "maximum"
      schema.max
    when "exclusiveMinimum"
      schema.min_exclusive
    when "exclusiveMaximum"
      schema.max_exclusive
    else
      schema.__send__(key.underscore) rescue schema[key]
    end
  end

  def compare(actual, expected, key)
    if actual.is_a?(Array)
      if actual.size != expected.size
        [ key ]
      else
        actual.zip(expected).map.with_index do |(ai, ei), i|
          compare(ai, ei, key + "/#{i}")
        end.flatten
      end
    elsif expected.is_a?(Hash)
      expected.keys.map do |key2|
        compare(get_value_of_schema(actual, key2), expected[key2], key + "/#{key2}")
      end.flatten
    else
      if actual == expected
        []
      else
        [ key ]
      end
    end
  end

  def format_schema(value)
    if value.is_a?(Array)
      value.map {|e| format_schema(e) }
    elsif value.is_a?(::JsonSchema::Schema)
      value.inspect_schema
    else
      value
    end
  end

  match do |actual|
    @errors = hash.each.with_object([]) do |(key, value), errors|
      errors.push(*compare(get_value_of_schema(actual, key), value, "#/" + key))
    end

    @errors.empty?
  end

  failure_message do |actual|
    "expect #{actual.inspect_schema} to be #{hash}\n" + \
    @errors.map {|e|
      actual_value   = JsonPointer::Evaluator.new(actual).evaluate(normalize_pointer(e))
      expected_value = JsonPointer::Evaluator.new(hash).evaluate(e)
       "  expect #{e}: #{actual_value} to be #{expected_value}"
    }.join("\n  ")
  end
end
