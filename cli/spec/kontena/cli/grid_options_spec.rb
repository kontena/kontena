require "kontena/cli/common"
require "kontena/cli/grid_options"
require 'json'

describe Kontena::Cli::GridOptions do
  let(:subject) do
    Class.new(Kontena::Command) do
      include Kontena::Cli::Common
      include Kontena::Cli::GridOptions
      def execute
        puts "grid:#{current_grid}"
        puts "master:#{current_master.name}"
      end
    end.new('')
  end

  before(:each) do
    RSpec::Mocks.space.proxy_for(File).reset
    allow(File).to receive(:readable?).and_return(true)
    allow(File).to receive(:exist?).and_return(true)
    allow(File).to receive(:read).and_return(
      {
        'current_server' => 'alias',
        'servers' => [
           {'name' => 'some_master', 'url' => 'some_master', 'grid' => 'somegrid'},
           {'name' => 'alias', 'url' => 'someurl', 'grid' => 'somegrid'}
        ]
      }.to_json
    )
    Kontena::Cli::Config.reset_instance
  end


  describe '--grid' do
    it 'sets the current_grid' do
      expect{subject.run(['--grid', 'foogrid'])}.to output(/grid:foogrid/).to_stdout
      expect{subject.run(['--grid', 'foogrid'])}.to output(/master:alias/).to_stdout
    end
  end

  describe '--master' do
    it 'sets the current master' do
      expect{subject.run(['--master', 'some_master'])}.to output(/master:some_master/).to_stdout
      expect{subject.run(['--master', 'some_master'])}.to output(/grid:somegrid/).to_stdout
    end

    it 'fails if master is not found' do
      expect{subject.run(['--master', 'foomaster'])}.to output(/not found/).to_stderr
    end
  end

  describe 'both --grid and --master' do
    it 'sets the current master and grid' do
      expect{subject.run(['--master', 'some_master', '--grid', 'foogrid'])}.to output(/master:some_master/).to_stdout
      expect{subject.run(['--master', 'some_master', '--grid', 'foogrid'])}.to output(/grid:foogrid/).to_stdout
    end
  end
end
