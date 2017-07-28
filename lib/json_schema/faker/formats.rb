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

      safe_domain
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

    # https://tools.ietf.org/html/rfc3849
    def ipv6(schema, hint: nil, position: nil)
      raise "invalid schema given" unless schema.format == "ipv6"

      [
        ->() { "2001:0db8:" + 6.times.map { "%04x" % rand(65535) }.join(":") },
        ->() { "2001:0DB8:" + 6.times.map { "%04X" % rand(65535) }.join(":") },
        ->() { "2001:db8:"  + 6.times.map {   "%x" % rand(65535) }.join(":") },
        ->() { "2001:DB8:"  + 6.times.map {   "%X" % rand(65535) }.join(":") },
      ].sample.call
    end

    def uri(schema, hint: nil, position: nil)
      raise "invalid schema given" unless schema.format == "uri"

      # TODO: urn
      ::Faker::Internet.url(safe_domain)
    end

    protected def safe_domain
      "example." + %w[ org com net ].sample
    end

    module_function *instance_methods
  end
end
