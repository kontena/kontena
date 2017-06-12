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
    expect(subject).to receive(:confirm).and_return(false)
    expect(File).to receive(:read).with('foo.yml').and_return("foo: bar\n")
    subject.run(['foo.yml'])
  end

  it 'dies if the yml contains something odd' do
    expect(File).to receive(:read).with('foo.yml').and_return("foo: bar\nbar:\n  foo:\n    - bar\n")
    expect(subject).to receive(:exit_with_error).with(/Invalid value/).and_call_original
    expect{subject.run(['--force', 'foo.yml'])}.to exit_with_error
  end

  it 'runs vault write for kv-pairs in yaml' do
    expect(File).to receive(:read).with('foo.yml').and_return("foo: bar\nbar: foo\n")
    expect(Kontena).to receive(:run).with(['vault', 'update', '--upsert', '--silent', 'foo', 'bar']).and_return(true)
    expect(Kontena).to receive(:run).with(['vault', 'update', '--upsert', '--silent', 'bar', 'foo']).and_return(true)
    subject.run(['--force', 'foo.yml'])
  end

  it 'runs vault rm for kv-pairs with null value in yaml' do
    expect(File).to receive(:read).with('foo.yml').and_return("foo: bar\nbar: null\n")
    expect(Kontena).to receive(:run).with(['vault', 'update', '--upsert', '--silent', 'foo', 'bar']).and_return(true)
    expect(Kontena).to receive(:run).with(['vault', 'rm', '--silent', '--force', 'bar']).and_return(true)
    subject.run(['--force', 'foo.yml'])
  end

  it 'runs vault rm for kv-pairs with empty value in yaml when --empty-is-null' do
    expect(File).to receive(:read).with('foo.yml').and_return("foo: bar\nbar:\n")
    expect(Kontena).to receive(:run).with(['vault', 'update', '--upsert', '--silent', 'foo', 'bar']).and_return(true)
    expect(Kontena).to receive(:run).with(['vault', 'rm', '--silent', '--force', 'bar']).and_return(true)
    subject.run(['--force', '--empty-is-null', 'foo.yml'])
  end

  it 'does not run vault rm for kv-pairs with empty value in yaml when no --empty-is-null' do
    expect(File).to receive(:read).with('foo.yml').and_return("foo: bar\nbar: \"\"\n")
    expect(Kontena).to receive(:run).with(['vault', 'update', '--upsert', '--silent', 'foo', 'bar']).and_return(true)
    expect(Kontena).to receive(:run).with(['vault', 'update', '--upsert', '--silent', 'bar', '']).and_return(true)
    expect(Kontena).not_to receive(:run).with(['vault', 'rm', '--silent', '--force', 'bar'])
    subject.run(['--force', 'foo.yml'])
  end

  it 'doesnt vault rm for kv-pairs with null value in yaml when --skip-null used' do
    expect(File).to receive(:read).with('foo.yml').and_return("foo: bar\nbar: null\n")
    expect(Kontena).to receive(:run).with(['vault', 'update', '--upsert', '--silent', 'foo', 'bar']).and_return(true)
    expect(Kontena).not_to receive(:run).with(['vault', 'rm', '--silent', '--force', 'bar'])
    subject.run(['--force', '--skip-null', 'foo.yml'])
  end
end

