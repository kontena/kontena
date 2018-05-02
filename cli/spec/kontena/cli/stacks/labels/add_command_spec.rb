require 'kontena/cli/stacks/label_command'
require 'kontena/cli/stacks/labels/add_command'

describe Kontena::Cli::Stacks::Labels::AddCommand do
  include ClientHelpers
  include OutputHelpers

  let(:name) { 'test-stack' }

  # shared endpoint - the same for all cases
  let(:endpoint) { "stacks/test-grid/#{name}" }

  # base stack definition - use it as is, or modify to accomodate specific test case
  let(:scratch) do
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
    let(:stack) { scratch }

    it "adds the labels" do
      expected = { "labels" => ['test=yes'] }
      expect(client).to receive(:patch).with(endpoint, expected)
      subject.run([name, 'test=yes'])
    end
  end

  context "for a stack with labels" do
    let(:stack) { scratch.merge("labels" => ['noop=yoop']) }

    it "merges original and new labels" do
      expected = { "labels" => ['noop=yoop', 'loop=maybe'] }
      expect(client).to receive(:patch).with(endpoint, expected)
      subject.run([name, 'loop=maybe'])
    end

    it "deduplicates labels" do
      expected = { "labels" => ['noop=yoop'] }
      expect(client).to receive(:patch).with(endpoint, expected)
      subject.run([name, 'noop=yoop'])
    end
  end
end