require 'spec_helper'

describe 'plugin commands' do
  context 'list' do
    it "returns list" do
      k = run('kontena plugin ls')
      expect(k.code).to eq(0)
    end
  end

  context 'install' do
    after(:each) do
      run('kontena plugin rm --force aws')
    end

    it 'installs plugin' do
      k = run('kontena plugin install aws')
      expect(k.code).to eq(0)
      k = run('kontena plugin ls')
      expect(k.out).to match(/aws/)
    end
  end

  context 'uninstall' do
    before(:each) do
      run('kontena plugin install aws')
    end

    it 'removes installed plugin' do
      k = run('kontena plugin uninstall --force aws')
      expect(k.code).to eq(0)
    end

    #it 'returns error if plugin is not installed' do
    #  k = run('kontena plugin uninstall --force asdasdasd')
    #  expect(k.code).not_to eq(0)
    #end
  end
end
