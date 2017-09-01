require 'kontena/cli/stacks/stack_name'

describe Kontena::Cli::Stacks::StackName do
  it 'can parse a stack string' do
    expect(described_class.new('user/stack').to_s).to eq 'user/stack'
    expect(described_class.new('user/stack:0.1.0').to_s).to eq 'user/stack:0.1.0'
    expect(described_class.new('user/stack', '0.1.0').to_s).to eq 'user/stack:0.1.0'
  end

  it 'can take a hash' do
    expect(described_class.new(user: 'foo', stack: 'stack', version: '0.1.0').to_s).to eq 'foo/stack:0.1.0'
  end

  it 'has accessors' do
    result = described_class.new('user/stack:0.1.0')
    expect(result.stack_name).to eq 'user/stack'
    expect(result.user).to eq 'user'
    expect(result.stack).to eq 'stack'
    expect(result.version).to eq '0.1.0'
  end
end
