RSpec.describe JsonSchema::Faker do
  Dir["suite/tests/draft4/**/*.json"].sort.each do |file|
    next if file.end_with?("definitions.json") # json shema does not support resolve ref over http
    next if file.end_with?("refRemote.json")   # json shema does not support resolve ref over http

    fcontext "from suite #{file}" do
      tests = JSON.parse(File.read(file))

      tests.each.with_index do |test, i|

        context "[#{i}]" do
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
