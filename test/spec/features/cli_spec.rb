require 'spec_helper'

describe 'cli' do
  it 'can run --help on all subcommands' do
    run('kontena complete --subcommand-tree').split(/[\r\n]/).each do |command|
      k = run(command + ' --help')
      expect(k.code).to eq(0)
      expect(k.out).to match(/Usage:/)
      expect(k.out).to match(/Options:/)
    end
  end
end
