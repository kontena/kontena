require 'kontena/cli/vault/export_command'

describe Kontena::Cli::Vault::ExportCommand do

  include RequirementsHelper

  let(:subject) do
    described_class.new(File.basename($0))
  end

  expect_to_require_current_master

  before(:each) do
    allow(Kontena::Cli::Config.instance).to receive(:current_master).and_return(Kontena::Cli::Config::Server.new)
  end

  it 'goes through the list of vault keys and outputs a yaml' do
    expect(Kontena).to receive(:run).with(['vault', 'ls', '--return']).and_return(['foo', 'bar'])
    expect(Kontena).to receive(:run).with(['vault', 'read', '--return', 'bar']).and_return('barbar')
    expect(Kontena).to receive(:run).with(['vault', 'read', '--return', 'foo']).and_return('foofoo')
    expect{subject.run([])}.to output(/bar: barbar\nfoo: foofoo/).to_stdout
  end

  it 'goes through the list of vault keys and outputs a json' do
    expect(Kontena).to receive(:run).with(['vault', 'ls', '--return']).and_return(['foo', 'bar'])
    expect(Kontena).to receive(:run).with(['vault', 'read', '--return', 'bar']).and_return('barbar')
    expect(Kontena).to receive(:run).with(['vault', 'read', '--return', 'foo']).and_return('foofoo')
    expect{subject.run(['--json'])}.to output(/\"bar\":\"barbar\",\"foo\":\"foofoo\"/).to_stdout
  end

end
