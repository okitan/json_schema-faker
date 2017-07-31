# coding: utf-8
Gem::Specification.new do |spec|
  spec.name          = "json_schema-faker"
  spec.version       = File.read(File.expand_path("VERSION", File.dirname(__FILE__))).chomp
  spec.authors       = ["okitan"]
  spec.email         = ["okitakunio@gmail.com"]

  spec.summary       = "generate fake data from json schema"
  spec.description   = "generate fake data from json schema"
  spec.homepage      = "https://github.com/okitan/json_schema-faker"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "json_schema", ">= 0.12.4"
  spec.add_dependency "pxeger"

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"

  # test
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "guard-rspec"

  # check pr
  spec.add_development_dependency "danger"
  spec.add_development_dependency "git_diff_parser"

  # debug
  spec.add_development_dependency "pry"
end
