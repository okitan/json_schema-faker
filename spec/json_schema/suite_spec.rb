RSpec.describe JsonSchema::Faker do
  def self.skip?(file, num)
    return "treat the rest of one_of as not is not supported" if file == "suite/tests/draft4/oneOf.json" && num == 1
    return "seems difficult"                                  if file == "suite/tests/draft4/not.json"   && num == 2

    false
  end

  Dir["suite/tests/draft4/**/*.json"].sort.each do |file|
    next if file == "suite/tests/draft4/definitions.json" # json shema does not support resolve ref over http
    next if file == "suite/tests/draft4/ref.json"         # they should be root schema and when I do it, faker will always return {}
    next if file == "suite/tests/draft4/refRemote.json"   # json shema does not support resolve ref over http

    fcontext "from suite #{file}" do
      tests = JSON.parse(File.read(file))

      tests.each.with_index do |test, i|
        context "[#{i}]", skip: skip?(file, i) do
          it_behaves_like "generating data from properties which passes validation" do
            let(:properties) do
              { "#{file}[#{i}]" => test["schema"] }
            end
          end
        end
      end
    end
  end
end
