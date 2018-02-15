require 'spec_helper'

describe 'cli' do
  it 'can run --help on all subcommands' do
    run('kontena complete --subcommand-tree').out.split(/[\r\n]/).reject { |cmd| cmd.empty? || cmd =~ /\[.+?\]/ }.each do |command|
      k = run!(command + ' --help')
      expect(k.out).to match(/Usage:/)
      expect(k.out).to match(/Options:/)
    end
  end
end
