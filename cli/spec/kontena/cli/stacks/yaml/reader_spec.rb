require 'kontena/cli/stacks/yaml/reader'

describe Kontena::Cli::Stacks::YAML::Reader do
  include FixturesHelpers

  let(:service_extender) { spy("Kontena::Cli::Stacks::YAML::ServiceExtender") }

  let(:env_file) do
    ['APIKEY=12345
', 'MYSQL_ROOT_PASSWORD=secret
', 'WP_ADMIN_PASSWORD=verysecret']
  end

  let(:valid_v3_result) do
    {
      'stack' => 'user/stackname',
      'version' => '2',
      'services' => {
        'wordpress' => {
          'image' => 'wordpress:4.1',
          'ports' => ['80:80'],
          'depends_on' => ['mysql'],
          'stateful' => true,
          'environment' => ['WORDPRESS_DB_PASSWORD=test_secret'],
          'instances' => 2,
          'deploy' => { 'strategy' => 'ha' },
          'secrets' => []
        },
        'mysql' => {
          'image' => 'mysql:5.6',
          'stateful' => true,
          'environment' => ['MYSQL_ROOT_PASSWORD=test_secret'],
          'secrets' => []
        }
      }
    }
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
      outcome = subject.execute
      expect(outcome[:errors].size).to eq(1)
    end
  end

  describe '#execute' do
    context 'when extending services' do
      context 'from external file' do
        subject do
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
          expect(subject.execute[:services]).to match array_including(
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
          expect(outcome[:errors]).to eq([{
            'docker-compose_v2.yml' =>[
              {
                'services' => {
                  'wordpress' => {
                    'networks' => 'key not expected'
                  }
                }
              }
            ]
          }])
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
          expect(subject.execute[:services].find { |s| s['name'] == 'app' }).to match hash_including(
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
        result = subject.execute
        services = result[:services]
        expect(services['wordpress']['image']).to eq('wordpress:4.1')
      end

      it 'interpolates default variables' do
        result = subject.execute
        services = result[:services]

        expect(services['wordpress']['environment']).to include('STACK=test', 'GRID=test-grid', 'PLATFORM=test-grid')
      end

      it 'interpolates ${VAR} variables' do
        result = subject.execute
        services = result[:services]
        expect(services['mysql']['image']).to eq('mariadb:latest')
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
        services = subject.execute[:services]
        expect(services['mysql']['environment'].first).to eq('INTERNAL_VAR=$INTERNAL_VAR')
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
          result = subject.execute[:services]
          expect(result['wordpress']['environment']).to eq(['WORDPRESS_DB_PASSWORD=test_secret'])
        end

        it 'does nothing to env array' do
          result = subject.execute[:services]
          expect(result['mysql']['environment']).to eq(['MYSQL_ROOT_PASSWORD=test_secret'])
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
          result = subject.execute[:services]
          expect(result['wordpress']['environment']).to eq([
            'WORDPRESS_DB_PASSWORD=test_secret',
            'APIKEY=12345',
            'MYSQL_ROOT_PASSWORD=secret',
            'WP_ADMIN_PASSWORD=verysecret'
            ])
        end

      end
    end

    it 'returns result hash' do
      outcome = subject.execute
      expect(outcome[:services]).to eq(valid_v3_result['services'])
    end

    context "For an invalid stack file" do
      subject do
        described_class.new(fixture_path('stack-invalid.yml'))
      end

      it 'returns validation errors' do
        outcome = subject.execute
        expect(outcome[:errors].size).to eq(1)
      end
    end
  end

  context 'when build option is string' do
    subject do
      described_class.new(fixture_path('kontena_build_v3.yml'))
    end

    it 'expands build option to absolute path' do
      outcome = subject.execute
      expect(outcome[:services]['webapp']['build']['context']).to eq(fixture_path(''))
    end
  end

  context 'when build option is Hash' do
    subject do
      described_class.new(fixture_path('kontena_build_v3.yml'))
    end

    it 'expands build context to absolute path' do
      outcome = subject.execute
      expect(outcome[:services]['webapp']['build']['context']).to eq(fixture_path(''))
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
        expect(options.dig('build', 'args')).to eq({
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
      name = subject.stack_name
      expect(name).to eq('stackname')
    end
  end

  context 'origins' do
    before do
      allow(File).to receive(:read)
        .with(fixture_path('kontena_v3.yml'))
        .and_return(fixture('kontena_v3.yml'))
    end

    it 'can read from a file' do
      allow(File).to receive(:read)
        .with(fixture_path('docker-compose_v2.yml'))
        .and_return(fixture('docker-compose-invalid.yml'))

      subject = described_class.new(fixture_path('kontena_v3.yml'))

      expect(subject.from_file?).to be_truthy
      expect(subject.execute[:registry]).to eq 'file://'
    end

    it 'can read from the registry' do
      allow(File).to receive(:read)
        .with(File.expand_path('docker-compose_v2.yml'))
        .and_return(fixture('docker-compose-invalid.yml'))

      stack_double = double
      allow_any_instance_of(Kontena::StacksCache::RegistryClientFactory).to receive(:cloud_auth?).and_return(true)
      expect(Kontena::StacksCache).to receive(:cache).with('foo/foo', nil).and_return(stack_double)
      expect(stack_double).to receive(:read).and_return(fixture('kontena_v3.yml'))
      instance = described_class.new('foo/foo')
      expect(instance.from_registry?).to be_truthy
      expect(instance.execute[:registry]).to eq instance.current_account.stacks_url
    end

    it 'can read from an url' do
      allow(File).to receive(:read)
        .with(File.expand_path('docker-compose_v2.yml'))
        .and_return(fixture('docker-compose-invalid.yml'))

      stub_request(:get, "http://foo.example.com/foo").to_return(:status => 200, :body => fixture('stack-with-liquid.yml'), :headers => {})
      allow_any_instance_of(described_class).to receive(:load_from_url).and_return(fixture('stack-with-liquid.yml'))
      instance = described_class.new('http://foo.example.com/foo')
      expect(instance.from_url?).to be_truthy
      expect(instance.execute[:registry]).to eq 'file://'
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
        expect(subject.execute[:services].size).to eq 5
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
      outcome = subject.execute

      expect(outcome[:variables]).to eq('asdf' => nil), subject.variables.inspect
      expect(outcome[:services]['test']['environment']).to eq nil
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

      expect(outcome[:variables]).to eq 'asdf' => 'test'
      expect(outcome[:services]['test']['environment']).to eq ['ASDF=test']
    end
  end
end
