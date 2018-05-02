require 'kontena/cli/stacks/label_command'
require 'kontena/cli/stacks/labels/remove_command'

describe Kontena::Cli::Stacks::Labels::RemoveCommand do
  include ClientHelpers
  include OutputHelpers

  # stack name
  let(:name) { 'test-stack' }

  # shared endpoint - the same for all cases
  let(:endpoint) { "stacks/test-grid/#{name}" }

  # scratch stack definition - use it as is, or modify to accomodate specific test case
  let(:scratch) do
    {
      'name' => name,
      'stack' => "foo/#{name}",
      'services' => [],
      'variables' => { 'foo' => 'bar' }
    }
  end

  before do
    # stub Kontena Master call with a stack as defined by specific context
    allow(client).to receive(:get).with(endpoint).and_return(stack)
  end

  context "for a stack without labels" do
    let(:stack) { scratch }

    it "does nothing" do
      expect(client).not_to receive(:patch).with(endpoint, [])
      subject.run([name, 'test=yes'])
    end
  end

  context "for a stack with labels" do
    let(:stack) { scratch.merge("labels" => ['noop=yoop', 'loop=maybe']) }

    it "removes only specified label" do
      expected = { "labels" => ['loop=maybe'] }
      expect(client).to receive(:patch).with(endpoint, expected)
      subject.run([name, 'noop=yoop'])
    end
  end
end