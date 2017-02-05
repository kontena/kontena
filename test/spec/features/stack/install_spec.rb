require 'spec_helper'

describe 'stack install' do
  after(:each) do
    run 'kontena stack rm --force simple'
  end

  context 'from file' do
    it 'installs a stack' do
      with_fixture_dir("stack/simple") do
        run 'kontena stack install'
      end
      k = run 'kontena stack show simple'
      expect(k.code).to eq(0)
      expect(k.out.match(/state: running/)).to be_truthy
    end

    it 'skips deploy with --no-deploy' do
      with_fixture_dir("stack/simple") do
        k = run 'kontena stack install --no-deploy'
        expect(k.code).to eq(0)
      end
      k = run 'kontena stack show simple'
      expect(k.code).to eq(0)
      expect(k.out.match(/state: initialized/)).to be_truthy
    end

    it 'returns error if file not found' do
      with_fixture_dir("stack/simple") do
        k = run 'kontena stack install foo.yml'
        expect(k.code).to eq(1)
        expect(k.out.match(/no such file/i)).to be_truthy
      end
    end

    it 'returns error if file is invalid' do
      with_fixture_dir("stack/simple") do
        k = run 'kontena stack install invalid.yml'
        expect(k.code).to eq(1)
        expect(k.out.match(/validation failed/i)).to be_truthy
      end
    end
  end
end
