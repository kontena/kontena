require "kontena/cli/stacks/show_command"

describe Kontena::Cli::Stacks::ShowCommand do

  include ClientHelpers

  describe '#execute' do
    it 'fetches stack info from master' do
      expect(client).to receive(:get).with('stacks/test-grid/test-stack').and_return(spy())
      subject.run(['test-stack'])
    end

    context '--values option' do
      let(:stack_response) do
        {
          'name' => 'stack-a',
          'stack' => 'foo/stack-a',
          'services' => [],
          'variables' => { 'foo' => 'bar' }
        }
      end

      it 'outputs a yaml of the stack variables and values' do
        expect(client).to receive(:get).with('stacks/test-grid/test-stack').and_return(stack_response)
        expect{subject.run(['--values', 'test-stack'])}.to output(/^foo: bar$/).to_stdout
      end
    end
  end
end
