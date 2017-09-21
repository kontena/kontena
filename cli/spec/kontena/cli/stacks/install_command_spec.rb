require "kontena/cli/stacks/install_command"

describe Kontena::Cli::Stacks::InstallCommand do

  include ClientHelpers
  include RequirementsHelper
  include FixturesHelpers

  mock_current_master

  before(:each) do
    ENV['STACK'] = nil
  end

  describe '#execute' do
    let(:stack_expectation) do
      {
        'name' => 'stackname',
        'stack' => 'user/stackname',
        'version' => '0.1.1',
        'registry' => 'file://',
        'services' => array_including(hash_including('name', 'image')),
        'variables' => {},
        'volumes' => [],
        'dependencies' => nil,
        'source' => /stack:/,
        'parent_name' => nil,
        'expose' => nil
      }
    end

    expect_to_require_current_master
    expect_to_require_current_master_token

    it 'sends stack to master' do
      expect(client).to receive(:post) do |path, data|
        expect(path).to eq 'grids/test-grid/stacks'
        expect(data).to match hash_including(stack_expectation)
        expect(data['services'].find { |s| s['name'] == 'wordpress' }['env']).to match array_including("WORDPRESS_DB_PASSWORD=stackname_secret")
        expect(data['services'].find { |s| s['name'] == 'mysql' }['env']).to match array_including("MYSQL_ROOT_PASSWORD=stackname_secret")
      end.and_return({})
      subject.run(['--no-deploy', fixture_path('kontena_v3.yml')])
    end

    it 'allows to override stack name' do
      expect(client).to receive(:post) do |path, data|
        expect(path).to eq 'grids/test-grid/stacks'
        expect(data).to match hash_including(stack_expectation.merge('name' => 'stack-a'))
        expect(data['services'].find { |s| s['name'] == 'wordpress' }['env']).to match array_including("WORDPRESS_DB_PASSWORD=stack-a_secret")
        expect(data['services'].find { |s| s['name'] == 'mysql' }['env']).to match array_including("MYSQL_ROOT_PASSWORD=stack-a_secret")
      end.and_return({})
      subject.run(['--no-deploy', '--name', 'stack-a', fixture_path('kontena_v3.yml')])
    end

    it 'accepts a stack name as filename' do
      allow(File).to receive(:exist?).with('user/stack:1.0.0').at_least(:once).and_return(false)
      expect(subject.loader_class).to receive(:for).with('user/stack:1.0.0').and_return(subject.loader_class.for(fixture_path('kontena_v3.yml')))
      allow(subject.loader_class).to receive(:for).and_call_original
      expect(client).to receive(:post).with(
        'grids/test-grid/stacks', hash_including(stack_expectation)
      )
      subject.run(['--no-deploy', 'user/stack:1.0.0'])
    end

    context '--[no-]deploy' do
      it 'runs deploy for the stack after install by default' do
        expect(client).to receive(:post).with(
          'grids/test-grid/stacks', hash_including(stack_expectation)
        )
        expect(Kontena).to receive(:run!).with(['stack', 'deploy', 'stackname']).and_return(true)
        subject.run([fixture_path('kontena_v3.yml')])
      end
    end

    context 'with a stack including dependencies' do

      it 'installs all the dependencies' do
        expect(Kontena).to receive(:run!).with(["stack", "install", "-n", "deptest-dep_1", "--parent-name", "deptest", '-v', 'dep_1.dep_var=1', '--no-deploy', fixture_path('stack-with-dependencies-dep-1.yml')])
        expect(Kontena).to receive(:run!).with(["stack", "install", "-n", "deptest-dep_2", "--parent-name", "deptest", "-v", "dep_var=1", '--no-deploy', fixture_path('stack-with-dependencies-dep-2.yml')])
        expect(client).to receive(:post).with('grids/test-grid/stacks', hash_including('stack' => 'user/depstack1', 'name' => 'deptest'))
        subject.run(['-n', 'deptest', '--no-deploy', '-v', 'dep_1.dep_1.dep_var=1', fixture_path('stack-with-dependencies.yml')])
      end
    end
  end

  context 'variable value input' do
    let(:expectation) do
      {
        'services' => array_including(
          hash_including(
            'name' => 'mysql',
            'image' => 'mysqlimage:latest',
            'env' => array_including(
              'TEST_VAR=abc'
            )
          ),
          hash_including(
            'name' => 'wordpress',
            'image' => 'wordpress:def'
          )
        )
      }
    end

    describe '--values-from' do
      it 'sends stack to master, loading values from a file' do
        allow(File).to receive(:exist?).with('values.yml').and_return(true)
        expect(File).to receive(:read).with('values.yml').and_return(
          YAML.dump('TEST_ENV_VAR' => 'abc', 'MYSQL_IMAGE' => 'mysqlimage', 'tag' => 'def')
        )
        expect(client).to receive(:post) do |path, data|
          expect(path).to eq 'grids/test-grid/stacks'
          expect(data).to match hash_including(expectation)
        end.and_return({})
        subject.run(['--no-deploy', '--values-from', 'values.yml', fixture_path('stack-with-variables.yml')])
      end
    end

    describe '--values-from-stack' do
      it 'sends stack to master, loading values from another stack on master' do
        expect(client).to receive(:get).with('stacks/test-grid/otherdep').and_return(
          'variables' => { 'foo' => 'bar' },
          'children' => [
            { 'name' => 'otherdep-dep_1' } ,
            { 'name' => 'otherdep-dep_2' }
          ]
        )

        expect(client).to receive(:get).with('stacks/test-grid/otherdep-dep_1').and_return(
          'variables' => { 'dep1var' => 'test' },
          'children' => [
            { 'name' => 'otherdep-dep_1-dep_1' }
          ]
        )

        expect(client).to receive(:get).with('stacks/test-grid/otherdep-dep_1-dep_1').and_return(
          'variables' => { 'dep1dep1var' => 'test11' },
          'children' => []
        )

        expect(client).to receive(:get).with('stacks/test-grid/otherdep-dep_2').and_return(
          'variables' => { 'dep2var' => 'test2' },
          'children' => [ ]
        )

        expect(Kontena).to receive(:run!).with(["stack", "install", "-n", "deptest-dep_1", "--parent-name", "deptest", '-v', 'dep1var=test', '-v', 'dep_1.dep1dep1var=test11', '--no-deploy', fixture_path('stack-with-dependencies-dep-1.yml')]).and_return(true)
        expect(Kontena).to receive(:run!).with(["stack", "install", "-n", "deptest-dep_2", "--parent-name", "deptest", '-v', 'dep_var=1', '-v', 'dep2var=test2', '--no-deploy', fixture_path('stack-with-dependencies-dep-2.yml')]).and_return(true)

        allow(client).to receive(:post).and_return({})

        subject.run(['--values-from-stack', 'otherdep', '-n', 'deptest', '--no-deploy', fixture_path('stack-with-dependencies.yml')])
      end
    end

    describe '-v' do
      it 'sends stack to master, loading values from command line' do
        expect(client).to receive(:post) do |path, data|
          expect(path).to eq 'grids/test-grid/stacks'
          expect(data).to match hash_including(expectation)
        end.and_return({})
        YAML.dump('TEST_ENV_VAR' => 'abc', 'MYSQL_IMAGE' => 'mysqlimage', 'tag' => 'def')
        subject.run(['--no-deploy', '-v', 'TEST_ENV_VAR=abc', '-v', 'MYSQL_IMAGE=mysqlimage', '-v', 'tag=def', fixture_path('stack-with-variables.yml')])
      end
    end

    describe 'combination of value inputs' do
      it 'can combine multiple inputs' do
        allow(File).to receive(:exist?).with('values.yml').and_return(true)
        expect(File).to receive(:read).with('values.yml').and_return(
          YAML.dump('TEST_ENV_VAR' => 'abc')
        )
        allow(client).to receive(:get).with('stacks/test-grid/foostack').and_return(
          'variables' => { 'MYSQL_IMAGE' => 'mysqlimage' }
        )
        expect(client).to receive(:post) do |path, data|
          expect(path).to eq 'grids/test-grid/stacks'
          expect(data).to match hash_including(expectation)
        end.and_return({})
        subject.run(['--no-deploy', '--values-from-stack', 'foostack', '--values-from', 'values.yml', '-v', 'tag=def', fixture_path('stack-with-variables.yml')])
      end
    end
  end
end
