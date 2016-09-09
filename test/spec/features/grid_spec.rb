require 'spec_helper'

describe 'grid commands' do
  it 'creates a new grid' do
    Kommando.new("kontena grid rm --force foo").run
    k = Kommando.new "$ kontena grid create foo"
    expect(k.run).to be_truthy
    k = Kommando.run "$ kontena grid ls"
    expect(k.out).to include("foo *")
    Kommando.new("kontena grid rm --force foo").run
  end
end
