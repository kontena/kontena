# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kontena/cli/version'

Gem::Specification.new do |spec|
  spec.name          = "kontena-cli"
  spec.version       = Kontena::Cli::VERSION
  spec.authors       = ["Kontena, Inc"]
  spec.email         = ["info@kontena.io"]
  spec.summary       = %q{Kontena command line tool}
  spec.description   = %q{Command-line client for the Kontena container and microservices platform}
  spec.homepage      = "https://www.kontena.io"
  spec.license       = "Apache-2.0"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.1.0"

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_runtime_dependency "excon", "~> 0.49.0"
  spec.add_runtime_dependency "tty-prompt", "0.13.1"
  spec.add_runtime_dependency "clamp", "~> 1.1.0"
  spec.add_runtime_dependency "ruby_dig", "~> 0.0.2"
  spec.add_runtime_dependency "launchy", "~> 2.4.3"
  spec.add_runtime_dependency "hash_validator", "~> 0.7.1"
  spec.add_runtime_dependency "retriable", "~> 2.1.0"
  spec.add_runtime_dependency "opto", "1.8.7"
  spec.add_runtime_dependency "semantic", "~> 1.5"
  spec.add_runtime_dependency "liquid", "~> 4.0.0"
  spec.add_runtime_dependency "tty-table", "~> 0.8.0"
  spec.add_runtime_dependency "kontena-websocket-client", "~> 0.1.1"
end
