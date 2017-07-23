require "json_schema/faker"

require "faker"

require "date"

class JsonSchema::Faker
  # Most format faker does not care other validations such as maxLength
  module Formats
    def date_time(schema)
      raise "invalid schema given" unless schema.format == "date-time"

      ::DateTime.now.rfc3339
    end

    def email(schema)
      raise "invalid schema given" unless schema.format == "email"

      ::Faker::Internet.safe_email
    end

    module_function *instance_methods
  end
end
