require 'spec_helper'

describe 'plugin support' do
  context 'spinner' do
    it 'is available by including Kontena::Cli::ShellSpinner' do
      k = run!('bundle exec ruby ' + fixture_dir('plugins') + 'spinner_test.rb')
      expect(k.out).to match /Testing spinner/
    end

    it 'is available by including Kontena::Cli::Common' do
      k = run!('bundle exec ruby ' + fixture_dir('plugins') + 'spinner_test_2.rb')
      expect(k.out).to match /Testing spinner/
    end

    it 'is available without including anything' do
      k = run!('bundle exec ruby ' + fixture_dir('plugins') + 'spinner_test_3.rb')
      expect(k.out).to match /Testing spinner/
    end
  end

  context 'client' do
    it 'does not need be required' do
      k = run!('bundle exec ruby ' + fixture_dir('plugins') + 'client_test.rb')
      expect(k.out).to match(/^example\.com/)
    end
  end

  context 'config' do
    it 'does not need to be required' do
      k = run!('bundle exec ruby ' + fixture_dir('plugins') + 'config_test.rb')
      expect(k.out).to match(/kontena_client/)
    end
  end

  context 'common' do
    it 'has access to the essentials' do
      run!('bundle exec ruby ' + fixture_dir('plugins') + 'common_test.rb')
    end
  end
end
