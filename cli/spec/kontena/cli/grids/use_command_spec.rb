
require 'kontena/cli/grids/use_command'

describe Kontena::Cli::Grids::UseCommand do

  include RequirementsHelper

  let(:client) do 
    Kontena::Client.new('https://foo', {access_token: 'abcd1234'})
  end

  let(:subject) do
    described_class.new(File.basename($0))
  end

  let(:server) do
    Kontena::Cli::Config::Server.new(url: 'https://localhost', token: 'abcd1234')
  end

  expect_to_require_current_master

  describe "#use" do
    before(:each) do
      expect(subject).to receive(:client).and_return(client)
      expect(Kontena::Cli::Config.instance).to receive(:write).and_return(true)
      expect(Kontena::Cli::Config.instance).to receive(:require_current_master).and_return(server)
      expect(Kontena::Cli::Config.instance).to receive(:current_master).and_return(server)
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

