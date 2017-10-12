require 'kontena/cli/volumes/list_command'

describe Kontena::Cli::Volumes::ListCommand do
  include ClientHelpers
  include OutputHelpers
  include RequirementsHelper

  expect_to_require_current_master
  expect_to_require_current_master_token

  mock_current_master

  let(:subject) { described_class.new("kontena") }
  let(:response)  do
    {
      'volumes' => [
        { 'id' => 'test-grid/testvol',
          'name' => 'testvol',
          'scope' => 'testscope',
          'driver' => 'testdriver',
          'created_at' => Time.parse('2001-01-01 12:00:00').to_s
        },
        { 'id' => 'test-grid/testvol2',
          'name' => 'testvol2',
          'scope' => 'testscope2',
          'driver' => 'testdriver2',
          'created_at' => Time.parse('2001-01-02 12:00:00').to_s
        }
      ]
    }
  end

  it 'lists volumes' do
    expect(client).to receive(:get).with('volumes/test-grid').and_return(response)
    expect{subject.run(['--no-long'])}.to output_table [
      ['testvol',  'testscope', 'testdriver', a_string_matching(/\d+ days ago/)],
      ['testvol2', 'testscope2', 'testdriver2', a_string_matching(/\d+ days ago/)]
    ]
  end

  context '--quiet' do
    it 'lists volume names' do
      expect(client).to receive(:get).with('volumes/test-grid').and_return(response)
      expect{subject.run(['-q'])}.to output_table([
        ['testvol'],
        ['testvol2']
      ]).without_header
    end
  end
end
