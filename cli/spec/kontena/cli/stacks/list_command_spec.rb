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
      allow(client).to receive(:get).with('grids/test-grid/stacks').and_return({
        'stacks' => []
      })
    end

    it "renders NAME as 1st column" do
      expect{subject.run([])}.to output_lines [/^NAME/]
    end

    it "renders STACK as 2nd column" do
      expect{subject.run([])}.to output_lines [/STACK/]
    end

    it "renders SERVICES_COUNT as 3rd column" do
      expect{subject.run([])}.to output_lines [/SERVICES_COUNT/]
    end

    it "renders STATE as 4th column" do
      expect{subject.run([])}.to output_lines [/STATE/]
    end

    it "renders PORTS as 5th column" do
      expect{subject.run([])}.to output_lines [/PORTS/]
    end

    it "renders LABELS as 6th column" do
      expect{subject.run([])}.to output_lines [/LABELS$/]
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
          'labels' => ['fqdn=about.me']
        }]
      })
    end

    it "outputs stack labels" do
      expect{subject.run([])}.to output_table [
        ["\e[2m\u229D\e[0m", 'stack-a', 'foo/stack-a:', '0', 'fqdn=about.me'],
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
        ["\e[2m\u229D\e[0m", 'stack-a', 'foo/stack-a:', '0', '-'],
      ]
    end
  end
end
