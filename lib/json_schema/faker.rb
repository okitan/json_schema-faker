require "json_schema"

require "pxeger"

module JsonSchema
  class Faker
    module Configuration
      attr_accessor :logger

      module_function :logger, :logger=
    end

    module Strategy
      require "json_schema/faker/strategy/simple"
    end

    def initialize(schema, options = {})
      @schema   = schema
      @options = options
    end

    def generate(hint: nil)
      strategy  = @options[:strategy] || Strategy::Simple.new

      Configuration.logger.debug "to generate against #{@schema.inspect_schema}" if Configuration.logger

      generated = strategy.call(@schema, hint: nil, position: "")
      Configuration.logger.debug "generated: #{generated.inspect}" if Configuration.logger

      generated
    end

    protected
  end
end
