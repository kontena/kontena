require_relative "../../../spec_helper"
require 'kontena/cli/vault/import_command'


describe Kontena::Cli::Vault::ImportCommand do

  include RequirementsHelper

  let(:subject) do
    described_class.new(File.basename($0))
  end

  before(:each) do
    allow(Kontena::Cli::Config.instance).to receive(:current_master).and_return(Kontena::Cli::Config::Server.new)
    allow(Kontena::Cli::Config.instance).to receive(:current_grid).and_return("foofoo")
  end

  expect_to_require_current_master

  it 'asks for confirmation' do
    expect(subject).to receive(:confirm).and_raise(RuntimeError, 'confirm')
    expect(File).to receive(:read).with('foo.yml').and_return("foo: bar\n")
    expect{subject.run(['foo.yml'])}.to raise_error(RuntimeError, 'confirm')
  end

  it 'dies if the yml contains something odd' do
    expect(File).to receive(:read).with('foo.yml').and_return({foo: 'bar', bar: { foo: ["bar"] }}.to_yaml)
    expect(subject).to receive(:exit_with_error).with(/Invalid value/).and_raise(RuntimeError, 'invalid')
    expect{subject.run(['foo.yml'])}.to raise_error(RuntimeError, 'invalid')
  end

  it 'runs vault write for kv-pairs in yaml' do
    expect(File).to receive(:read).with('foo.yml').and_return("foo: bar\nbar: foo\n")
    expect(Kontena).to receive(:run).with(/vault update.*foo bar/).and_return(0)
    expect(Kontena).to receive(:run).with(/vault update.*bar foo/).and_return(0)
    subject.run(['--force', 'foo.yml'])
  end

  it 'runs vault rm for kv-pairs with null value in yaml' do
    expect(File).to receive(:read).with('foo.yml').and_return("foo: bar\nbar: null\n")
    expect(Kontena).to receive(:run).with(/vault update.*foo bar/).and_return(0)
    expect(Kontena).to receive(:run).with(/vault rm.*bar/).and_return(0)
    subject.run(['--force', 'foo.yml'])
  end

  it 'runs vault rm for kv-pairs with empty value in yaml when --empty-is-null' do
    expect(File).to receive(:read).with('foo.yml').and_return("foo: bar\nbar:\n")
    expect(Kontena).to receive(:run).with(/vault update.*foo bar/).and_return(0)
    expect(Kontena).to receive(:run).with(/vault rm.*bar/).and_return(0)
    subject.run(['--force', '--empty-is-null', 'foo.yml'])
  end

  it 'does not run vault rm for kv-pairs with empty value in yaml when no --empty-is-null' do
    expect(File).to receive(:read).with('foo.yml').and_return("foo: bar\nbar: \"\"\n")
    expect(Kontena).to receive(:run).with(/vault update.*foo bar/).and_return(0)
    expect(Kontena).to receive(:run).with(/vault update.*bar ''/).and_return(0)
    expect(Kontena).not_to receive(:run).with(/vault rm.*bar/)
    subject.run(['--force', 'foo.yml'])
  end

  it 'doesnt vault rm for kv-pairs with null value in yaml when --skip-null used' do
    expect(File).to receive(:read).with('foo.yml').and_return("foo: bar\nbar: null\n")
    expect(Kontena).to receive(:run).with(/vault update.*foo bar/).and_return(0)
    expect(Kontena).not_to receive(:run).with(/vault rm.*bar/)
    subject.run(['--force', '--skip-null', 'foo.yml'])
  end

end

