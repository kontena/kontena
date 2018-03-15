require "kontena/cli/stacks/list_command"

describe Kontena::Cli::Stacks::ListCommand do
  include ClientHelpers
  include RequirementsHelper
  include OutputHelpers

  expect_to_require_current_master
  expect_to_require_current_master_token

  describe '#execute' do
    it 'fetches stacks from master' do
      stacks = {
        'stacks' => []
      }
      expect(client).to receive(:get).with('grids/test-grid/stacks').and_return(stacks)
      subject.run([])
    end
  end

  describe '#build_depths' do
    it 'returns an array of hashes with "depth" field updated' do
      items = [
        {
          'depth' => 0, #stack1 1
          'name' => 'stack1_d1',
          'children' => [
            { 'name' => 'stack2_d2' },
            { 'name' => 'stack4_d2' }
          ]
        },
        {
          'depth' => 0,
          'name' => 'stack2_d2',
          'children' => [
            { 'name' => 'stack3_d3' },
          ]
        },
        {
          'depth' => 0,
          'name' => 'stack3_d3',
          'children' => []
        },
        {
          'depth' => 0,
          'name' => 'stack4_d2',
          'children' => [
            { 'name' => 'stack5_d3' }
          ]
        },
        {
          'depth' => 0,
          'name' => 'stack5_d3',
          'children' => []
        }
      ].shuffle

      subject.build_depths(items).each do |item|
        depth_expectation = item['name'].split('_d').last.to_i
        expect(item['depth']).to eq depth_expectation
      end
    end
  end

  context "command output layout" do
    before do
      allow(client).to receive(:get).with('grids/test-grid/stacks').and_return('stacks' => [])
    end

    it "renders expected columns layout" do
      expect{subject.run([])}.to output_table([]).with_header(
        %w(NAME STACK SERVICES_COUNT STATE PORTS LABELS)
      )
    end
  end

  context "with stack and labels" do
    before do
      allow(client).to receive(:get).with('grids/test-grid/stacks').and_return({
        'stacks' => [{
          'name' => 'stack-a',
          'stack' => 'foo/stack-a',
          'services' => [],
          'variables' => { 'foo' => 'bar' },
          'children' => [],
          'labels' => ['fqdn=fence.gru']
        }]
      })
    end

    it "outputs stack labels" do
      expect{subject.run([])}.to output_table [
        [anything, 'stack-a', 'foo/stack-a:', '0', 'fqdn=fence.gru'],
      ]
    end
  end

  context "with stack and no labels" do
    before do
      allow(client).to receive(:get).with('grids/test-grid/stacks').and_return({
        'stacks' => [{
          'name' => 'stack-a',
          'stack' => 'foo/stack-a',
          'services' => [],
          'variables' => { 'foo' => 'bar' },
          'children' => [],
        }]
      })
    end

    it "outputs stack and dash" do
      expect{subject.run([])}.to output_table [
        [anything, 'stack-a', 'foo/stack-a:', '0', '-'],
      ]
    end
  end

  context "with stack and excessively lengthy labels" do
    before do
      allow(client).to receive(:get).with('grids/test-grid/stacks').and_return({
        'stacks' => [{
          'name' => 'stack-a',
          'stack' => 'foo/stack-a',
          'services' => [],
          'variables' => { 'foo' => 'bar' },
          'children' => [],
          'labels' => ['noop=first', 'loop=second', 'xor=bitwise', 'and=bitwise']
        }]
      })
    end

    it "outputs stack and ellipsis in tty" do
      # stub stdin to emulate kontena stack ls
      allow($stdin).to receive(:tty?).and_return(true)
      expect{subject.run([])}.to output_table [
        [anything, 'stack-a', 'foo/stack-a:', '0', 'noop=first,loop=se...'],
      ]
    end

    it "outputs stack and labels in non-tty" do
      # stub stdin to emulate kontena stack ls | grep xyz
      allow($stdin).to receive(:tty?).and_return(false)
      expect{subject.run([])}.to output_table [
        [anything, 'stack-a', 'foo/stack-a:', '0', 'noop=first,loop=second,xor=bitwise,and=bitwise'],
      ]
    end
  end
end
