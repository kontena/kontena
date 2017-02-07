# Commented untill we know how to refactor the modules to be more easily tested
# require_relative '../../../../../spec_helper'
# require 'kontena/cli/stacks/yaml/opto/service_link_resolver'
#
# describe Kontena::Cli::Stacks::YAML::Opto::Resolvers::ServiceLink do
#   it 'works?' do
#     prompt = double(:prompt)
#     menu = double(:menu)
#     allow(subject).to receive(:prompt).and_return(prompt)
#     expect(prompt).to receive(:select).and_yield(menu)
#     expect(subject).to receive(:get_services).and_return(
#       [
#         {'name' => 'lb', 'stack' => {'name' => 'null'}},
#         {'name' => 'lb', 'stack' => {'name' => 'foo'}}
#       ]
#     )
#     expect(menu).to receive(:choice).with('lb', 'null/lb')
#     expect(menu).to receive(:choice).with('foo/lb', 'foo/lb')
#
#   end
# end
