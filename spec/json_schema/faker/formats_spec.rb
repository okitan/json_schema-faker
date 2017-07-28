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

  context "#hostname" do
    it "is valid" do
      schema = JsonSchema.parse!("format" => "hostname")
      expect(described_class.hostname(schema)).to be_valid_for(schema)
    end
  end

  context "#ipv4" do
    it "is valid" do
      schema = JsonSchema.parse!("format" => "ipv4")
      expect(described_class.ipv4(schema)).to be_valid_for(schema)
    end
  end

  context "ipv6" do
    it "is valid" do
      schema = JsonSchema.parse!("format" => "ipv6")
      expect(described_class.ipv6(schema)).to be_valid_for(schema)
    end
  end

  context "uri" do
    it "is valid" do
      schema = JsonSchema.parse!("format" => "uri")
      expect(described_class.uri(schema)).to be_valid_for(schema)
    end
  end
end
