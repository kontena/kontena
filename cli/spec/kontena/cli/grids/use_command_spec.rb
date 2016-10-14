
require_relative "../../../spec_helper"
require 'kontena/cli/grids/use_command'

describe Kontena::Cli::Grids::UseCommand do

  include RequirementsHelper

  let(:subject) do
    described_class.new(File.basename($0))
  end

  let(:server) do
    Kontena::Cli::Config::Server.new(name: 'server', url: 'https://localhost', token: Kontena::Cli::Config::Token.new(access_token: 'abcd1234', parent_type: :master, parent_name: 'server'))
  end

  let(:client) do
    double
  end

  expect_to_require_current_master

  describe "#use" do
    before(:each) do
      allow(Kontena::Cli::Config.instance).to receive(:servers).and_return([server])
      expect(subject).to receive(:client).and_return(client)
      expect(subject.class.requires_current_master_token).to be_truthy
      expect(Kontena::Cli::Config.instance).to receive(:write).and_return(true)
      expect(Kontena::Cli::Config.instance).to receive(:current_master).at_least(:once).and_return(server)
    end

    it "should set the current grid in config" do
      expect(server).to receive(:grid=).with('foo')
      expect(client).to receive(:get).and_return(
        { 'grids' => [
            { 'name' => 'foo' }
          ]
        }
      )
      subject.run(['foo'])
    end
  end
end

