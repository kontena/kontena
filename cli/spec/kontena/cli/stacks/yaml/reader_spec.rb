require 'kontena/cli/stacks/yaml/reader'

describe Kontena::Cli::Stacks::YAML::Reader do
  include FixturesHelpers

  let(:service_extender) { spy("Kontena::Cli::Stacks::YAML::ServiceExtender") }

  let(:env_file) do
    ['APIKEY=12345
', 'MYSQL_ROOT_PASSWORD=secret
', 'WP_ADMIN_PASSWORD=verysecret']
  end

  before(:each) do
    allow_any_instance_of(described_class).to receive(:env)
      .and_return( { 'STACK' => 'test', 'GRID' => 'test-grid', 'PLATFORM' => 'test-grid' } )
  end

  describe '#initialize' do
    subject do
      described_class.new(fixture_path('kontena_v3.yml'))
    end

    it 'reads given file' do
      expect(File).to receive(:read)
        .with(fixture_path('kontena_v3.yml'))
        .and_return(fixture('kontena_v3.yml'))

      subject
    end
  end

  context 'when yaml file is malformed' do
    subject do
      described_class.new(fixture_path('kontena-malformed-yaml.yml'))
    end

    it 'exits the execution' do
      expect {
        subject.execute
      }.to raise_error(StandardError)
    end
  end

  context 'when service config is not hash' do
    subject do
      described_class.new(fixture_path('kontena-not-hash-service-config.yml'))
    end

    it 'returns error' do
      subject.execute
      expect(subject.errors.size).to eq(1)
    end
  end

  describe '#execute' do

    let(:subject) do
      described_class.new(fixture_path('kontena_v3.yml'))
    end

    it 'returns result hash' do
      result = subject.execute
      expect(result).to be_kind_of(Hash)
      %w(
        stack
        version
        name
        registry
        expose
        services
        volumes
        dependencies
        source
        variables
        parent_name
      ).each do |k|
        expect(result.key?(k)).to be_truthy
      end
    end

    context 'when extending services' do
      context 'from external file' do
        let(:subject) do
          described_class.new(fixture_path('kontena_v3.yml'))
        end

        before do
          [:exist?, :read].each do |meth|
            allow(File).to receive(meth).with(fixture_path('docker-compose_v2.yml')).and_call_original
            allow(File).to receive(meth).with(fixture_path('kontena_v3.yml')).and_call_original
          end
        end

        it 'extends services from an external file' do
          expect(File).to receive(:read).with(fixture_path('docker-compose_v2.yml')).and_call_original
          expect(subject.execute['services']).to match array_including(
            hash_including(
              "instances"=>2,
              "image"=>"wordpress:4.1",
              "env"=>["WORDPRESS_DB_PASSWORD=test_secret"],
              "links"=>[{"name"=>"mysql", "alias"=>"mysql"}],
              "ports"=>[{"ip"=>"0.0.0.0", "container_port"=>80, "node_port"=>80, "protocol"=>"tcp"}],
              "stateful"=>true,
              "strategy"=>"ha",
              "name"=>"wordpress"
            ),
            hash_including(
              "instances"=>nil,
              "image"=>"mysql:5.6",
              "env"=>["MYSQL_ROOT_PASSWORD=test_secret"],
              "links"=>[],
              "ports"=>[],
              "stateful"=>true,
              "name"=>"mysql"
            )
          )
        end

        it 'merges validation errors' do
          expect(File).to receive(:read).with(fixture_path('docker-compose_v2.yml')).and_return(fixture('docker-compose-invalid.yml'))
          outcome = subject.execute
          expect(subject.errors).to match array_including(
            hash_including(
              'docker-compose_v2.yml' => array_including(
                hash_including(
                  'services' => { 'wordpress' => { 'networks' => 'key not expected' } }
                )
              )
            )
          )
        end
      end

      context 'from the same file' do
        subject do
          described_class.new(fixture_path('stack-internal-extend.yml'))
        end

        before do
          [:exist?, :read].each do |meth|
            allow(File).to receive(meth).with(fixture_path('stack-internal-extend.yml')).and_call_original
          end
        end

        it 'extends services from the same file' do
          app_svc = subject.execute['services'].find { |s| s['name'] == 'app' }
          expect(app_svc).not_to be_nil
          puts app_svc.inspect
          expect(app_svc).to match hash_including(
            "image" => "base:latest",
            "instances" => 2,
            "env" => [
              "TEST1=test1",
              "TEST2=changed"
            ],
            "stateful" => true
          )
        end
      end
    end

    context 'variable interpolation' do
      subject do
        described_class.new(fixture_path('stack-with-variables.yml'))
      end

      before(:each) do
        allow(File).to receive(:read)
          .with(fixture_path('docker-compose_v2.yml'))
          .and_return(fixture('docker-compose_v2.yml'))
        allow(File).to receive(:read)
          .with(fixture_path('stack-with-variables.yml'))
          .and_return(fixture('stack-with-variables.yml'))

        allow_any_instance_of(described_class).to receive(:env).and_return(
          {
            'STACK' => 'test',
            'GRID' => 'test-grid',
            'PLATFORM' => 'test-grid',
            'TAG' => '4.1'
          }
        )
        allow(ENV).to receive(:[]).with('TAG').and_return('4.1')
        allow(ENV).to receive(:[]).with('TEST_ENV_VAR').and_return('foo')
        allow(ENV).to receive(:[]).with('MYSQL_IMAGE').and_return('mariadb:latest')
      end

      it 'interpolates $VAR variables' do
        expect(subject.execute['services']).to match array_including(hash_including('image' => 'wordpress:4.1'))
      end

      it 'interpolates default variables' do
        expect(subject.execute['services']).to match array_including(
          hash_including(
            'name' => 'wordpress', 'env' => array_including(
              'STACK=test', 'GRID=test-grid', 'PLATFORM=test-grid'
            )
          )
        )
      end

      it 'interpolates ${VAR} variables' do
        expect(subject.execute['services']).to match array_including(hash_including('name' => 'mysql', 'image' => 'mariadb:latest'))
      end

      it 'warns about empty variables' do
        allow(ENV).to receive(:[])
          .with('MYSQL_IMAGE')
          .and_return('')
        allow(ENV).to receive(:[])
          .with('TAG')
          .and_return('4.1')

        expect {
          subject.execute
        }.to output("Value for MYSQL_IMAGE is not set. Substituting with an empty string.\n").to_stdout
      end

      it 'replaces $$VAR variables to $VAR format' do
        allow_any_instance_of(described_class).to receive(:env).and_return(
          {
            'STACK' => 'test',
            'GRID' => 'test-grid'
          }
        )
        allow(ENV).to receive(:[]).with('TAG').and_return('4.1')
        allow(ENV).to receive(:[]).with('TEST_ENV_VAR').and_return('foo')
        allow(ENV).to receive(:[]).with('MYSQL_IMAGE').and_return('foo')

        expect(subject.execute['services']).to match array_including(
          hash_including('name' => 'mysql', 'env' => array_including('INTERNAL_VAR=$INTERNAL_VAR'))
        )
      end

      it 'raises runtime error for undeclared variables' do
        subject.variables.delete(subject.variables.option('test_var'))
        expect{subject.execute}.to raise_error(RuntimeError, /Undeclared variable 'test_var'/)
      end

      it 'considers variables declared when they are listed as to: env targets' do
        subject.variables.option('tag').to[:env] = "BAG"
        expect{subject.execute}.to raise_error(RuntimeError, /Undeclared variable 'TAG'/)
        subject.variables.option('tag').to[:env] = "TAG"
        expect{subject.execute}.not_to raise_error
      end
    end

    context 'environment variables' do
      subject do
        described_class.new(fixture_path('stack-with-env-file.yml'))
      end

      context "with an empty env file" do
        before(:each) do
          allow(File).to receive(:readlines).with('.env').and_return([])
        end

        it 'converts env hash to array' do
          expect(subject.execute['services']).to match array_including(hash_including('name' => 'wordpress', 'env' => ['WORDPRESS_DB_PASSWORD=test_secret']))
        end

        it 'does nothing to env array' do
          expect(subject.execute['services']).to match array_including(
            hash_including('name' => 'mysql', 'env' => ['MYSQL_ROOT_PASSWORD=test_secret'])
          )
        end
      end

      context 'when introduced env_file' do
        before(:each) do
          allow(File).to receive(:readlines).with('.env').and_return(env_file)
        end

        it 'discards comment lines' do
          result = env_file
          result << "#COMMENTLINE"
          allow(File).to receive(:readlines).with('.env').and_return(result)

          variables = subject.send(:read_env_file, '.env')
          expect(variables).to eq([
            'APIKEY=12345',
            'MYSQL_ROOT_PASSWORD=secret',
            'WP_ADMIN_PASSWORD=verysecret'
            ])
        end

        it 'discards empty lines' do
          result = env_file
          result << '
    '
          allow(File).to receive(:readlines).with('.env').and_return(result)
          variables = subject.send(:read_env_file, '.env')
          expect(variables).to eq([
            'APIKEY=12345',
            'MYSQL_ROOT_PASSWORD=secret',
            'WP_ADMIN_PASSWORD=verysecret'
            ])
        end

        it 'merges variables' do
          expect(subject.execute['services']).to match array_including(
            hash_including(
              'name' => 'wordpress',
              'env' => [
                'WORDPRESS_DB_PASSWORD=test_secret',
                'APIKEY=12345',
                'MYSQL_ROOT_PASSWORD=secret',
                'WP_ADMIN_PASSWORD=verysecret'
              ]
            )
          )
        end
      end
    end
  end

  context 'when build option is string' do
    subject do
      described_class.new(fixture_path('kontena_build_v3.yml'))
    end

    it 'expands build option to absolute path' do
      outcome = subject.execute
      expect(outcome['services']).to match array_including(
        hash_including(
          'name' => 'webapp',
          'build' => hash_including('context' => fixture_path(''))
        )
      )
    end
  end

  context 'when build option is Hash' do
    subject do
      described_class.new(fixture_path('kontena_build_v3.yml'))
    end

    it 'expands build context to absolute path' do
      outcome = subject.execute
      expect(outcome['services']).to match array_including(
        hash_including(
          'name' => 'webapp',
          'build' => hash_including('context' => fixture_path(''))
        )
      )
    end
  end

  context 'normalize_build_args' do
    subject do
      described_class.new(fixture_path('kontena_build_v3.yml'))
    end

    context 'when build option is string' do
      it 'skips normalizing' do
        options = {
          'build' => '.'
        }
        expect {
          subject.send(:normalize_build_args, options)
        }.not_to raise_error
      end
    end

    context 'when build arguments option is Hash' do
      it 'does not do anything' do
        options = {
          'build' => {
            'context' => '.',
            'args' => {
              'foo' => 'bar'
            }
          }
        }

        subject.send(:normalize_build_args, options)
        expect(options.dig('build', 'args')).to eq({
          'foo' => 'bar'
        })
      end
    end

    context 'when build arguments option is Array' do
      it 'converts it to array' do
        options = {
          'build' => {
            'context' => '.',
            'args' => ['foo=bar']
          }
        }

        subject.send(:normalize_build_args, options)
        expect(options['build']['args']).to eq({
          'foo' => 'bar'
        })
      end
    end
  end

  describe '#stack_name' do
    subject do
      described_class.new(fixture_path('kontena_v3.yml'))
    end

    it 'returns name for v3' do
      name = subject.loader.stack_name.stack
      expect(name).to eq('stackname')
    end
  end

  context 'origins' do
    before do
      ['docker-compose_v2.yml', 'kontena_v3.yml'].each do |file|
        [:exist?, :read].each do |meth|
          allow(File).to receive(meth)
            .with(fixture_path(file))
            .and_call_original
        end
      end
    end

    it 'can read from a file' do
      subject = described_class.new(fixture_path('kontena_v3.yml'))
      expect(subject.loader.origin).to eq 'file'
      expect(subject.execute['registry']).to eq 'file://'
    end

    it 'can read from the registry' do
      allow(File).to receive(:exist?)
        .with(/foo\/foo$/)
        .and_return(false)
      instance = described_class.new('foo/foo')
      expect(instance.loader.origin).to eq 'registry'
    end

    it 'can read from an url' do
      allow(File).to receive(:exist?)
        .with(/\/foo$/)
        .and_return(false)
      instance = described_class.new('http://foo.example.com/foo')
      expect(instance.loader.origin).to eq 'uri'
    end
  end

  context "using Liquid templates" do
    context "for a valid stack file" do
      subject do
        described_class.new(fixture_path('stack-with-liquid.yml'))
      end

      it 'does not interpolate liquid into variables' do
        expect(subject.variables.value_of('grid_name')).to eq '{{ GRID }} test'
      end

      it 'interpolates variables into services' do
        expect(subject.execute['services'].size).to eq 5
      end
    end

    context "for invalid Liquid syntax" do
      subject do
        described_class.new(fixture_path('stack-with-invalid-liquid.yml'))
      end

      it 'raises' do
        expect{subject.execute}.to raise_error(Liquid::SyntaxError)
      end
    end
  end

  context "for an undefined variable" do
    subject do
      described_class.new(fixture_path('stack-with-liquid-undefined.yml'))
    end

    it "raises an undefined variable error" do
      expect{subject.execute}.to raise_error(Liquid::UndefinedVariable, /undefined variable asdflol/)
    end
  end

  context "for an optional variable that is not defined" do
    subject do
      described_class.new(fixture_path('stack-with-liquid-optional.yml'))
    end

    before do
      allow(ENV).to receive(:[]).with('asdf').and_return(nil)
    end

    it "omits the env" do
      result = subject.execute
      expect(result['variables']).to match hash_including('asdf' => nil)
      expect(result['services']).to match array_including(
        hash_including('name' => 'test', 'env' => nil)
      )
    end
  end

  context "for an optional variable that is defined" do
    subject do
      described_class.new(fixture_path('stack-with-liquid-optional.yml'))
    end

    before do
      allow(ENV).to receive(:[]).with('asdf').and_return('test')
    end

    it "defines the env" do
      outcome = subject.execute
      expect(outcome['variables']).to match hash_including('asdf' => 'test')
      expect(outcome['services']).to match array_including(
        hash_including('name' => 'test', 'env' => ['ASDF=test'])
      )
    end
  end
end
