require "kontena/cli/stacks/upgrade_command"
require 'json'

describe Kontena::Cli::Stacks::UpgradeCommand do

  include ClientHelpers
  include RequirementsHelper
  include FixturesHelpers

  mock_current_master

  describe '#execute' do

    let(:stack_expectation) do
      {
        name: 'stack-name',
        stack: 'user/stackname',
        version: '0.0.1',
        registry: 'file://',
        services: array_including(hash_including('name', 'image')),
        variables: {},
        volumes: [],
        dependencies: nil,
        source: /stack:/,
        parent_name: nil,
        expose: nil
      }
    end

    let(:stack_response) do
      JSON.parse(
        JSON.dump(stack_expectation.merge(services: [{name: 'foo', image: 'bar'}], source: 'foo'))
      )
    end

    let(:stack) do
      {
        'name' => 'stack-a',
        'stack' => 'foo/stack-a',
        'services' => []
      }
    end

    let(:stack_with_different_stack_name) do
      {
        'name' => 'stack-a',
        'stack' => 'foo/stack-z',
        'services' => []
      }
    end

    let(:defaults) do
      { 'foo' => 'bar' }
    end

    #let(:stack_response) do
    #  {
    #    'name' => 'stack-a',
    #    'stack' => 'foo/stack-a',
    #    'services' => [],
    #    'variables' => defaults
    #  }
    #end

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
      expect(client).to receive(:put).with('stacks/test-grid/stack-a', hash_including(stack_expectation.merge(name: 'stack-a')))
      subject.run(['--no-deploy', 'stack-a', fixture_path('kontena_v3.yml')])
    end

    it 'requires confirmation when master stack is different than input stack' do
      expect(client).to receive(:get).with('stacks/test-grid/stack-b').and_return(stack_response.merge('stack' => 'foo/otherstack'))
      expect(subject).to receive(:confirm).with(/Replacing stack foo\/otherstack on master with user\/stackname/).and_call_original
      expect{subject.run(['stack-b',  fixture_path('kontena_v3.yml')])}.to exit_with_error
    end

    it 'triggers deploy by default' do
      expect(client).to receive(:get).with('stacks/test-grid/stack-a').and_return(stack_response)
      allow(client).to receive(:put).with(
        'stacks/test-grid/stack-a', anything
      ).and_return({})
      expect(Kontena).to receive(:run!).with(['stack', 'deploy', 'stack-a']).once
      subject.run(['stack-a', fixture_path('kontena_v3.yml')])
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
  end
end
