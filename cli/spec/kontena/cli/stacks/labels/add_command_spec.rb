require 'kontena/cli/stacks/label_command'
require 'kontena/cli/stacks/labels/add_command'

describe Kontena::Cli::Stacks::Labels::AddCommand do
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
    it "adds the labels" do
      # arrange
      expected = { "labels" => ['test=yes'] }
      # assert
      expect(client).to receive(:patch).with(endpoint, expected)
      # act
      subject.run([name, 'test=yes'])
    end
  end

  context "for a stack with labels" do
    # update original stack definition
    let(:stack) { scratch.merge("labels" => ['noop=yoop']) }

    it "merges original and new labels" do
      # arrange
      expected = { "labels" => ['noop=yoop', 'loop=maybe'] }
      # assert
      expect(client).to receive(:patch).with(endpoint, expected)
      # act
      subject.run([name, 'loop=maybe'])
    end

    it "deduplicates labels" do
      # arrange
      expected = { "labels" => ['noop=yoop'] }
      # assert
      expect(client).to receive(:patch).with(endpoint, expected)
      # act
      subject.run([name, 'noop=yoop'])
    end
  end
end