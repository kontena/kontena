require "kontena/cli/stacks/upgrade_command"
require 'json'

describe Kontena::Cli::Stacks::UpgradeCommand do

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
        'name' => 'stack-name',
        'stack' => 'user/stackname',
        'version' => '0.1.1',
        'registry' => 'file://',
        'services' => array_including(hash_including('name', 'image')),
        'variables' => {},
        'volumes' => [],
        'dependencies' => nil,
        'source' => /stack:/,
        'expose' => nil
      }
    end

    let(:stack_response) do
      stack_expectation.merge('services' => [{'name' => 'foo', 'image' => 'bar'}], 'source' => 'foo')
    end

    before(:each) do
      allow(File).to receive(:read).with('kontena.yml').and_return(fixture('kontena_v3.yml'))
      allow(File).to receive(:exist?).with('kontena.yml').and_return(true)
      allow(subject.loader_class).to receive(:for).and_call_original
    end

    expect_to_require_current_master
    expect_to_require_current_master_token

    it 'uses kontena.yml as default stack file' do
      expect(subject.instance(['stack-name']).source).to eq 'kontena.yml'
      expect(subject.instance(['stack-name']).stack_name).to eq 'stack-name'
    end

    it 'sends stack to master' do
      expect(client).to receive(:get).with('stacks/test-grid/stack-a').and_return(stack_response)
      expect(client).to receive(:put).with('stacks/test-grid/stack-a', hash_including(stack_expectation.merge('name' => 'stack-a'))).and_return(true)
      subject.run(['--no-deploy', '--force', 'stack-a', fixture_path('kontena_v3.yml')])
    end

    it 'requires confirmation when master stack is different than input stack' do
      expect(client).to receive(:get).with('stacks/test-grid/stack-b').and_return(stack_response.merge('stack' => 'foo/otherstack'))
      expect(subject).to receive(:confirm).and_call_original
      expect{subject.run(['stack-b', fixture_path('kontena_v3.yml')])}.to exit_with_error.and output(/- stack-b from foo\/otherstack to user\/stackname/).to_stdout
    end

    it 'triggers deploy by default' do
      expect(client).to receive(:get).with('stacks/test-grid/stack-a').and_return(stack_response)
      allow(client).to receive(:put).with(
        'stacks/test-grid/stack-a', anything
      ).and_return({})
      expect(Kontena).to receive(:run!).with(['stack', 'deploy', 'stack-a']).once
      subject.run(['--force', 'stack-a', fixture_path('kontena_v3.yml')])
    end

    context '--no-deploy option' do
      it 'does not trigger deploy' do
        expect(client).to receive(:get).with('stacks/test-grid/stack-a').and_return(stack_response)
        allow(client).to receive(:put).with(
          'stacks/test-grid/stack-a', anything
        ).and_return({})
        expect(Kontena).not_to receive(:run!).with(['stack', 'deploy', 'stack-a'])
        subject.run(['--no-deploy', 'stack-a', fixture_path('kontena_v3.yml')])
      end
    end

    context 'with a stack including dependencies' do

      let(:expectation)     {{ 'name' => 'deptest', 'stack' => 'user/depstack1' }}
      let(:expectation_1)   {{ 'name' => 'deptest-dep_1', 'stack' => 'user/depstack1child1'}}
      let(:expectation_1_1) {{ 'name' => 'deptest-dep_1-dep_1', 'stack' => 'user/depstack1child1child1', 'services' => array_including(hash_including('image' => 'image:2')) }}
      let(:expectation_2)   {{ 'name' => 'deptest-dep_2', 'stack' => 'user/depstack1child2', 'services' => array_including(hash_including('image' => 'image:1')), 'variables' => hash_including('dep_var' => 1) }}

      let(:response)     { expectation.merge('parent' => nil, 'children' => [{'name' => 'deptest-dep_1'}, {'name' => 'deptest-dep_2'}], 'services' => [])  }
      let(:response_1)   { expectation_1.merge('parent' => { 'name' => 'deptest' }, 'children' => [{'name' => 'deptest-dep_1-dep_1'}], 'services' => []) }
      let(:response_1_1) { expectation_1_1.merge('parent' => { 'name' => 'deptest-dep_1' }, 'children' => [], 'services' => []) }
      let(:response_2)   { expectation_2.merge('parent' => { 'name' => 'deptest' }, 'children' => [], 'variables' => {}, 'services' => []) }

      before  do
        allow(subject).to receive(:fetch_master_data).with('deptest').and_return(response)
        allow(subject).to receive(:fetch_master_data).with('deptest-dep_1').and_return(response_1)
        allow(subject).to receive(:fetch_master_data).with('deptest-dep_1-dep_1').and_return(response_1_1)
        allow(subject).to receive(:fetch_master_data).with('deptest-dep_2').and_return(response_2)
      end

      it 'upgrades all dependencies' do
        expect(client).to receive(:put).with('stacks/test-grid/deptest-dep_2', hash_including(expectation_2)).and_return(true)
        expect(client).to receive(:put).with('stacks/test-grid/deptest-dep_1-dep_1', hash_including(expectation_1_1)).and_return(true)
        expect(client).to receive(:put).with('stacks/test-grid/deptest-dep_1', hash_including(expectation_1)).and_return(true)
        expect(client).to receive(:put).with('stacks/test-grid/deptest', hash_including(expectation)).and_return(true)
        subject.run(['--force', '--no-deploy', '-v', 'dep_2.dep_var=1', 'deptest', fixture_path('stack-with-dependencies.yml')])
      end

      context 'when a dependency has been removed' do
        it 'warns if a stack no longer in the dependency chain would be removed' do
          expect(subject).to receive(:confirm).and_call_original
          expect{subject.run(['--no-deploy', 'deptest', fixture_path('stack-with-dependencies-dep_2-removed.yml')])}.to exit_with_error.and output(/- deptest-dep_2.*data will be lost/m).to_stdout
        end
      end

      context 'when a dependency has been added' do
        it 'installs any new stacks in the dependency chain' do
          allow(client).to receive(:put).and_return(true)
          expect(Kontena).to receive(:run!).with(["stack", "install", "--name", "deptest-dep_3", "--no-deploy", "--parent-name", "deptest", fixture_path('stack-with-dependencies-dep-3.yml')]).and_return(true)
          subject.run(['--no-deploy', '--force', '-v', 'dep_2.dep_var=1', 'deptest', fixture_path('stack-with-dependencies-dep_3-added.yml')])
        end
      end
    end
  end
end
