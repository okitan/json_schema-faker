require "json_schema/faker/formats"

RSpec.describe JsonSchema::Faker::Formats do
  context "#date_time" do
    it "is valid" do
      schema = JsonSchema.parse!("format" => "date-time")
      expect(described_class.date_time(schema)).to be_valid_for(schema)
    end
  end

  context "#email" do
    it "is valid" do
      schema = JsonSchema.parse!("format" => "email")
      expect(described_class.email(schema)).to be_valid_for(schema)
    end
  end
end
