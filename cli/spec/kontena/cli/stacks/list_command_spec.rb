require "kontena/cli/stacks/list_command"

describe Kontena::Cli::Stacks::ListCommand do
  include ClientHelpers
  include RequirementsHelper

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
end
