require "json_schema/faker/formats"

RSpec.describe JsonSchema::Faker::Formats do
  context "#date_time" do
    it "is parsable as date-time" do
      schema = { "format" => "date-time" }
      expect(described_class.date_time(schema)).to satisfy {|ret| DateTime.rfc3339(ret) }
    end
  end
end
