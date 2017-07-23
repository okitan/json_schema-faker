require "json_schema/faker"

require "date"

class JsonSchema::Faker
  module Formats
    def date_time(schema)
      raise "invalid schema given" unless schema["format"] == "date-time"

      DateTime.now.rfc3339
    end
    module_function *instance_methods
  end
end
