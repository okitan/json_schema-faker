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

  config.order = :random

  Kernel.srand config.seed
end

RSpec::Matchers.define :be_valid_for do |schema|
  match do |actual|
    schema.validate(actual).first
  end

  failure_message do |actual|
    errors = schema.validate(actual).last

    "expected that #{actual} would be valid for #{schema.inspect_schema}:\n  " + errors.join("\n  ")
  end
end

# this requires properties
RSpec.shared_examples "generating data from properties which passes validation" do
  it do
    raw_schema = {
      "id"         => self.__id__.to_s,
      "$schema"    => "http://json-schema.org/draft-04/schema#",
      "properties" => properties,
      "required"   => properties.keys,
    }

    @schema = JsonSchema.parse!(raw_schema)
    @schema.expand_references!
    expect(described_class.new(@schema).generate).to be_valid_for(@schema)
  end
end
