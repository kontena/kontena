require 'spec_helper'

describe 'plugin uninstall' do
  context 'with the aws plugin installed' do
    before(:each) do
      run! 'kontena plugin install aws'
    end

    it 'removes installed plugin' do
      run! 'kontena plugin uninstall aws'

      k = run! 'kontena plugin ls'
      expect(k.out).to_not match(/aws/)
    end
  end
end
