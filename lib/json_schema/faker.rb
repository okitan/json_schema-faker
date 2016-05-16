require "json_schema"

module JsonSchema
  class Faker
    # TODO:
    # strategy to use for faker
    def initialize(schema, options = {})
      @schema  = schema

      @options = options
    end

    def generate
      #{ "integer" => "string" }
      {}
    end
  end
end
