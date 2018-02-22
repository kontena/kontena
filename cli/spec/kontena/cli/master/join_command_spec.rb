require 'kontena/cli/master/join_command'

describe Kontena::Cli::Master::JoinCommand do

  include ClientHelpers

  let(:subject) do
    described_class.new(File.basename($0))
  end

  it 'calls master login with proper join options' do
    expect(Kontena).to receive(:run!).with(%w(master login --join xyz someurl))
    subject.run(%w(someurl xyz))
  end

  it 'calls master login with remote option' do
    expect(Kontena).to receive(:run!).with(%w(master login --join xyz --remote someurl))
    subject.run(%w(--remote someurl xyz))
  end

  it 'calls master login with name option' do
    expect(Kontena).to receive(:run!).with(%w(master login --join xyz --name somename someurl))
    subject.run(%w(--name somename someurl xyz))
  end

  it 'calls master login with verbose option' do
    expect(Kontena).to receive(:run!).with(%w(master login --join xyz --verbose someurl))
    subject.run(%w(--verbose someurl xyz))
  end
end
