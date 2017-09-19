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

  context 'For a stack with a broken link' do
    it 'Returns an error' do
      with_fixture_dir("stack/links") do
        k = run 'kontena stack install broken.yml'
        expect(k.code).to eq(1)
        expect(k.out).to match /service a has missing links: nope/m
      end
    end
  end

  context 'For a stack with stop_grace_period' do
    it 'creates stack service with stop_grace_period' do
      with_fixture_dir("stack/simple") do
        run 'kontena stack install stop-period.yml'
      end
      k = run 'kontena service show simple/redis'
      expect(k.code).to eq(0)
      expect(k.out.match(/stop_grace_period: 23s/)).to be_truthy
    end
  end

  context 'For a stack with read_only' do
    it 'creates stack service with read_only and updates it properly' do
      with_fixture_dir("stack/read_only") do
        run 'kontena stack install redis.yml'
      end
      k = run 'kontena service show simple/redis'
      expect(k.code).to eq(0)
      expect(k.out.match(/read_only: yes/)).to be_truthy
      with_fixture_dir("stack/read_only") do
        run 'kontena stack upgrade simple redis_read_only_false.yml'
      end
      k = run 'kontena service show simple/redis'
      expect(k.code).to eq(0)
      expect(k.out.match(/read_only: no/)).to be_truthy, k.out
    end
  end

  context 'For a stack with dependencies' do

    after do
      %w(twemproxy twemproxy-redis_from_registry twemproxy-redis_from_yml).each do |stack|
        run "kontena stack rm --force #{stack}"
      end
    end

    it 'installs all dependencies' do
      with_fixture_dir("stack/depends") do
        k = run 'kontena stack install'
        expect(k.code).to eq (0)
      end
      k = run 'kontena stack ls -q'
      expect(k.out.split(/[\r\n]/)).to match array_including('twemproxy', 'twemproxy-redis_from_registry', 'twemproxy-redis_from_yml')
    end
  end
end
