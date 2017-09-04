require 'kontena/cli/stacks/yaml/stack_file_loader'

describe Kontena::Cli::Stacks::YAML::StackFileLoader do
  include FixturesHelpers

  before do
    allow(File).to receive(:exist?).and_return(false)
    [:exist?, :read].each do |meth|
      ['docker-compose_v2.yml', 'kontena_v3.yml'].each do |file|
        allow(File).to receive(meth)
          .with(fixture_path(file))
          .and_call_original
      end
    end
  end

  describe '#for' do
    it 'returns a loader for a file' do
      expect(described_class.for(fixture_path('kontena_v3.yml')).origin).to eq 'file'
    end

    it 'returns a loader for an url' do
      expect(described_class.for('http://foofoo.com').origin).to eq 'uri'
    end

    it 'returns a loader for a registry path' do
      expect(described_class.for('foo/foo:1.2.3').origin).to eq 'registry'
    end

    it 'raises if nothing matches' do
      expect{described_class.for('this-should-not-exist').origin}.to raise_error(RuntimeError)
    end
  end

  context 'instance methods' do
    let(:subject) { described_class.for(fixture_path('kontena_v3.yml')) }

    describe '#reader' do
      it 'returns a YAML::Reader' do
        expect(subject.reader).to be_a Kontena::Cli::Stacks::YAML::Reader
        expect(subject.reader.loader).to eq subject
      end
    end

    describe '#content' do
      it 'returns the raw content' do
        expect(File).to receive(:read).with(fixture_path('kontena_v3.yml')).and_call_original
        expect(subject.content).to match /^stack:/
      end
    end

    describe '#stack_name' do
      it 'returns an accessor to stack string components' do
        expect(subject.stack_name.user).to eq 'user'
        expect(subject.stack_name.stack).to eq 'stackname'
        expect(subject.stack_name.version).to eq '0.1.1'
        expect(subject.stack_name.to_s).to eq 'user/stackname:0.1.1'
      end
    end

    describe '#yaml' do
      it 'returns a yaml from the file content' do
        expect(subject.yaml['stack']).to eq 'user/stackname'
      end
    end

    describe '#dependencies' do
      before do
        [:exist?, :read].each do |meth|
          Dir.glob(File.join(File.dirname(fixture_path('stack-with-dependencies.yml')), 'stack-with-dep*.yml')).each do |file|
            puts file
            allow(File).to receive(meth)
              .with(file)
              .and_call_original
          end
        end
      end

      let(:subject) { described_class.for(fixture_path('stack-with-dependencies.yml')) }

      it 'returns an array of hashes' do
        expect(subject.dependencies).to match array_including(
          hash_including(
            'name' => 'dep_1',
            'stack' => /dep-1.yml$/,
            'variables' => {},
            'depends' => array_including(
              hash_including(
                'name' => 'dep_1',
                'stack' => /-1-1.yml$/,
                'variables' => { 'dep_var' => 2 }
              )
            )
          ),
          hash_including(
            'name' => 'dep_2',
            'stack' => /dep-2.yml$/,
            'variables' => { 'dep_var' => 1 }
          )
        )
      end
    end
  end
end
