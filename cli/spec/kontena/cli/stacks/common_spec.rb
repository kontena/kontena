require "kontena/cli/stacks/common"
require "kontena/cli/stacks/yaml/reader"

describe Kontena::Cli::Stacks::Common do

  let(:klass) do
    Class.new(Kontena::Command) do
      include Kontena::Cli::Stacks::Common
      include Kontena::Cli::Common
      include Kontena::Cli::Stacks::Common::StackNameParam
      include Kontena::Cli::Stacks::Common::StackFileOrNameParam
      include Kontena::Cli::Stacks::Common::StackNameOption
      include Kontena::Cli::Stacks::Common::StackValuesToOption
      include Kontena::Cli::Stacks::Common::StackValuesFromOption
    end
  end

  let(:subject) { klass.new('') }

  context 'stack yaml reader methods' do
    let(:reader) { double(:reader) }

    before(:each) do
      allow(reader).to receive(:execute).and_return({ errors: [], notifications: [] })
      allow(reader).to receive(:raw_content).and_return("")
      allow(reader).to receive(:stack_name).and_return('foo')
      allow(subject).to receive(:set_env_variables).and_return(true)
    end

    describe '#stack_read_and_dump' do
      it 'passes args to reader' do
        expect(Kontena::Cli::Stacks::YAML::Reader).to receive(:new).with('foo', values: { 'value' => 'value' }, defaults: { 'default' => 'default' }).and_return(reader)
        subject.stack_read_and_dump('foo', name: 'name', values: { 'value' => 'value' }, defaults: { 'default' => 'default' })
      end

      it 'returns a stack hash' do
        expect(Kontena::Cli::Stacks::YAML::Reader).to receive(:new).and_return(reader)
        expect(subject.stack_read_and_dump('foo')).to be_kind_of Hash
      end
    end

    describe '#stack_from_yaml' do
      it 'passes args to reader' do
        expect(Kontena::Cli::Stacks::YAML::Reader).to receive(:new).with('foo', values: { 'value' => 'value' }, defaults: { 'default' => 'default' }).and_return(reader)
        subject.stack_from_yaml('foo', name: 'name', values: { 'value' => 'value' }, defaults: { 'default' => 'default' })
      end

      it 'returns a stack hash' do
        expect(Kontena::Cli::Stacks::YAML::Reader).to receive(:new).and_return(reader)
        expect(subject.stack_from_yaml('foo')).to be_kind_of Hash
      end
    end

    describe '#reader_from_yaml' do
      it 'passes args to reader' do
        expect(Kontena::Cli::Stacks::YAML::Reader).to receive(:new).with('foo', values: { 'value' => 'value' }, defaults: { 'default' => 'default' }).and_return(reader)
        subject.reader_from_yaml('foo', name: 'name', values: { 'value' => 'value' }, defaults: { 'default' => 'default' })
      end

      it 'returns a reader' do
        expect(Kontena::Cli::Stacks::YAML::Reader).to receive(:new).and_return(reader)
        expect(subject.reader_from_yaml('foo')).to eq reader
      end
    end
  end

  describe '#stack_name' do
  end

  describe '#stack_from_reader' do
  end

  describe '#stack_from_yaml' do
  end

  describe '#require_config_file' do
  end

  describe '#generate_volumes' do
  end

  describe '#generate_services' do
  end

  describe '#set_env_variables' do
  end

  describe '#current_dir' do
  end

  describe '#display_notifications' do
  end

  describe '#hint_on_validation_notifications' do
  end

  describe '#abort_on_validation_errors' do
  end

  describe '#stacks_client' do
  end
end
