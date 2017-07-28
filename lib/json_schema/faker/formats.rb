require "json_schema/faker"

require "faker"

require "date"

class JsonSchema::Faker
  # Most format faker does not care other validations such as maxLength
  module Formats
    def date_time(schema, hint: nil, position: nil)
      raise "invalid schema given" unless schema.format == "date-time"

      ::DateTime.now.rfc3339
    end

    def email(schema, hint: nil, position: nil)
      raise "invalid schema given" unless schema.format == "email"

      ::Faker::Internet.safe_email
    end

    # https://tools.ietf.org/html/rfc2606
    def hostname(schema, hint: nil, position: nil)
      raise "invalid schema given" unless schema.format == "hostname"

      "example." + %w[ org com net ].sample
    end

    # https://tools.ietf.org/html/rfc5737
    def ipv4(schema, hint: nil, position: nil)
      raise "invalid schema given" unless schema.format == "ipv4"

      [
        ->() { "192.0.2.#{(0..255).to_a.sample}" },
        ->() { "198.51.100.#{(0..255).to_a.sample}" },
        ->() { "203.0.113.#{(0..255).to_a.sample}" },
      ].sample.call
    end

    module_function *instance_methods
  end
end
