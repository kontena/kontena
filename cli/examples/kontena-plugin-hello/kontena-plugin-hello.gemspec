# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kontena/plugin/hello'

Gem::Specification.new do |spec|
  spec.name          = "kontena-plugin-hello"
  spec.version       = Kontena::Plugin::Hello::VERSION
  spec.authors       = ["Kontena, Inc."]
  spec.email         = ["info@kontena.io"]

  spec.summary       = "Kontena hello world plugin"
  spec.description   = "This plugin is just an example"
  spec.homepage      = "https://github.com/kontena/kontena/cli/examples/kontena-plugin-hello"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'kontena-cli', '>= 0.16.0.pre2'
  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
end
