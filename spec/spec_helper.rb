require "bundler/setup"
require "json_schema/faker"

if ENV["DEBUG"]
  require "pry"

  require "logger"
  logger = Logger.new($stderr)
  logger.level = case ENV["DEBUG"]
                 when "1"; Logger::INFO
                 when "2"; Logger::DEBUG
                 else      Logger::WARN
                 end
  JsonSchema::Faker::Configuration.logger = logger
end

Dir["spec/support/**/*.rb"].sort.each {|file| load file }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  config.example_status_persistence_file_path = "spec/examples.txt"

  config.disable_monkey_patching!

  #config.warnings = true

  #config.order = :random

  # TODO:
  def complete_schema(schema)
    schema = Marshal.load(Marshal.dump(schema))

    if %w[ minimum maximum ].any? {|key| schema.has_key?(key) }
      schema.merge("type" => "number")
    elsif %w[ minLength maxLength pattern ].any? {|key| schema.has_key?(key) }
      schema.merge("type" => "string")
    elsif %w[ items minItems maxItems uniqueItems ].any? {|key| schema.has_key?(key)}
      schema.merge("type" => "array").tap do |s|
        if s["items"]
          s["items"].map! {|e| complete_schema(e) }
        end
      end
    elsif %w[ minProperties maxProperties required properties additionalProperties patternProperties dependencies ].any? {|key| schema.has_key?(key) }
      schema.merge("type" => "object").tap do |s|
        if s["properties"]
          s["properties"].values.map! {|e| complete_schema(e) }
          s["required"] = s["properties"].keys unless s["required"]
        end
      end
    elsif %w[ oneOf anyOf allOf ].any? {|key| schema.has_key?(key) }
      schema.tap do |s|
        s["oneOf"].map! {|e| complete_schema(e) } if s["oneOf"]
        s["anyOf"].map! {|e| complete_schema(e) } if s["anyOf"]
        s["allOf"].map! {|e| complete_schema(e) } if s["allOf"]
      end
    else
      schema
    end
  end

  Kernel.srand config.seed
end
