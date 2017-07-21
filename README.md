# JsonSchema::Faker [![Build Status](https://travis-ci.org/okitan/json_schema-faker.svg?branch=master)](https://travis-ci.org/okitan/json_schema-faker)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'json_schema-faker'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install json_schema-faker

## Usage

```ruby
require "json_schema/faker"

raw_schema = {
  "id" => "https://example.com/schema.json",
  "$schema"    => "http://json-schema.org/draft-04/schema#",
  "properties" => { "a" => { "enum" => [ "e", "n", "u", "m" ] } },
  "required"   => [ "a" ],
}

schema = JsonSchema.parse!(raw_schema)

JsonSchema::Faker.new(schema).generate #=> { "a" => "e" }
```

Note: It is too difficult to correspond to complex schema.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/json_schema-faker. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

### Run tests

before running `rake spec`, run `git submodule init && git submodule update`

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
