require 'spec_helper'

describe 'complete' do
  it 'outputs subcommand tree with --subcommand-tree' do
    k = run 'kontena complete --subcommand-tree'
    expect(k.code).to eq(0)
    expect(k.out).to match(/^kontena grid show$/)
    expect(k.out).to match(/^kontena stack install$/)
    expect(k.out).to match(/^kontena service restart$/)
    expect(k.out).to match(/^kontena volume list$/)
    expect(k.out).to match(/^kontena master user role add$/)
    expect(k.out).to match(/^kontena master user role add foo$/)
    expect(k.out.split(/[\r\n]/).size > 100).to be_truthy
  end

  it 'can complete subcommands' do
    k = run 'kontena complete kontena'
    expect(k.out).to match(/^stack$/)
    expect(k.out).to match(/^vault$/)
    expect(k.out).to match(/^whoami$/)
  end

  it 'can complete subsubcommands' do
    k = run 'kontena complete kontena stack'
    expect(k.out).to match(/^install$/)
    expect(k.out).to match(/^deploy$/)
  end

  it 'can complete subsubsubcommands' do
    k = run 'kontena complete kontena master user'
    expect(k.out).to match(/^invite$/)
  end

  it 'can complete subsubsubsubcommands' do
    k = run 'kontena complete kontena master user role'
    expect(k.out).to match(/^add$/)
    expect(k.out).to match(/^remove$/)
  end

  it 'can complete master names' do
    k = run 'kontena complete kontena master use'
    expect(k.out).to match(/e2e/)
  end

  context 'master queries' do
    it 'can complete node names' do
      k = run 'kontena complete kontena node show'
      expect(k.out).to match(/online/)
    end

    it 'can complete grid names' do
      k = run 'kontena complete kontena grid show'
      expect(k.out).to match(/e2e/)
    end
  end
end
