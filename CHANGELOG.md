## 0.6.2

- Fixed
  - #16

## 0.6.1

- Fixed
- hint-example descending

## 0.6.0

- Added
- support of default faker against format
- support for copying format in take_logical_and_of_schema

## 0.5.2

- Added
  - support of schema dependency for JsonSchema::Faker::Strategy::Simple
  - validate default and return only if valid
- Fixed
  - fixes bug of disruption in JsonSchema::Faker::Util.take_logical_and_of_schema
  - fixes bug of not merged in JsonSchema::Faker::Strategy::Simple#compact_schema

## 0.5.1

- Added
  - support for copying pattern in take_logical_and_of_schema

## 0.5.0

- Added
  - ::JsonSchema::Faker::Util. utility for json_schema
- Removed
  - ::JsonSchema::Faker::Strategy::Simple.merge_schema! is removed. use ::JsonSchema::Faker::Util.take_logical_and_of_schema instead.

## 0.4.0

- Added
  - Greedy strategy to use properties as much as possible (suitable to response generation)

## 0.3.0

- Added
  - can add faker to format

## 0.2.0

- Added
  - support example as hint

## 0.1.1

- Added
  - refactor and improve generation

## 0.1.0

- initial release
