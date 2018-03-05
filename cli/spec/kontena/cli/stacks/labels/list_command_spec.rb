require 'kontena/cli/stacks/label_command'
require 'kontena/cli/stacks/labels/list_command'

describe Kontena::Cli::Stacks::Labels::ListCommand do
  include ClientHelpers
  include OutputHelpers

  # stack name
  let :name do
    'test-stack'
  end

  # shared endpoint - the same for all cases
  let :endpoint do
    "stacks/test-grid/#{name}"
  end

  # scratch stack definition - use it as is, or modify to accomodate specific test case
  let :scratch do
    {
      'name' => name,
      'stack' => "foo/#{name}",
      'services' => [],
      'variables' => { 'foo' => 'bar' }
    }
  end

  before do
    # stub Kontena Master call
    allow(client).to receive(:get).with(endpoint).and_return(stack)
  end

  context "for a stack without labels" do
    # original stack definition
    let(:stack) { scratch }
    it "outputs nothing" do
      # act & assert
      expect{subject.run([name])}.to output_lines []
    end
  end

  context "for a stack with labels" do
    # update original stack definition
    let(:stack) { scratch.merge("labels" => expected) }
    let(:expected) { ['noop=yoop', 'loop=maybe'] }

    it "outputs one label per line" do
      # act & assert
      expect{subject.run([name])}.to output_lines expected
    end
  end
end