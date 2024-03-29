# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'schemic/parser/version'

Gem::Specification.new do |spec|
   spec.name          = "schemic_parser"
   spec.version       = Schemic::Parser::VERSION
   spec.authors       = ["Pavel «Malo» Skrylev"]
   spec.email         = ["majioa@yandex.ru"]

   spec.summary       = %q{Schemic Parser parse an XML/HTML document to hashly-structured format}
   spec.description   = %q{Schemic Parser parse an XML/HTML document to hashly-structured format,
                           prepared to import to a DB, or just serialize it and save it as is}
   spec.homepage      = "https://github.com/majioa/schemic_parser"
   spec.license       = "MIT"

   # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
   # to allow pushing to a single host or delete this section to allow pushing to any host.
   if spec.respond_to?(:metadata)
      spec.metadata["allowed_push_host"] = "https://rubygems.org"
   else
      raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
   end

   spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
   spec.bindir        = "exe"
   spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
   spec.require_paths = ["lib"]

   spec.add_runtime_dependency "nokogiri", "~> 1.13", ">= 1.13.2"
   spec.add_runtime_dependency "rdoba", "~> 0.9", ">= 0.9.4"
   spec.add_development_dependency "bundler", "2.2.33"
   spec.add_development_dependency "rake", ">= 12.3.3"
   spec.add_development_dependency "pry", "~> 0.13", ">= 0.13.1"
   spec.add_development_dependency "cucumber", "~> 5.2"
   spec.add_development_dependency "rspec-json_expectations", "~> 2.2"
   spec.add_development_dependency "shoulda-matchers-cucumber", "~> 1.0", ">= 1.0.1"
end
