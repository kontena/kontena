require 'spec_helper'

describe 'stack install' do

  after(:each) do
    run 'kontena stack rm --force simple'
  end

  context 'from registry' do
    before do
      # the two specs use the same stack name
      wait_until_container_gone 'hello-ascii.lb-1'
      wait_until_container_gone 'hello-ascii.web-1'
    end

    after do
      run "kontena stack rm --force hello-ascii"
    end

    context 'config from file' do
      it 'installs a stack' do
        run! "kontena stack install -v scaling=1 kontena/hello-ascii"
        run! 'kontena stack show hello-ascii'
      end
    end

    context 'config from env' do
      before do
        @old_env = {
          'KONTENA_URL' => ENV['KONTENA_URL'],
          'KONTENA_TOKEN' => ENV['KONTENA_TOKEN'],
          'KONTENA_GRID' => ENV['KONTENA_GRID']
        }
        k = run! "kontena master current --url"
        ENV['KONTENA_URL'] = k.out.strip
        k = run! "kontena master token current --token"
        ENV['KONTENA_TOKEN'] = k.out.strip
        k = run! "kontena grid current --name"
        ENV['KONTENA_GRID'] = k.out.strip
      end

      after do
        @old_env.each do |k,v|
          ENV[k] = v
        end
      end

      it 'installs a stack' do
        run! "kontena stack install -v scaling=1 kontena/hello-ascii"
        run! 'kontena stack show hello-ascii'
      end
    end
  end

  context 'from file' do

    it 'installs a stack' do
      with_fixture_dir("stack/simple") do
        run! 'kontena stack install'
      end
      k = run! 'kontena stack show simple'
      expect(k.out.match(/state: running/)).to be_truthy
    end

    it 'skips deploy with --no-deploy' do
      with_fixture_dir("stack/simple") do
        k = run! 'kontena stack install --no-deploy'
      end
      k = run! 'kontena stack show simple'
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
        run! 'kontena stack install stop-period.yml'
      end
      k = run! 'kontena service show simple/redis'
      expect(k.out.match(/stop_grace_period: 23s/)).to be_truthy
    end
  end

  context 'For a stack with read_only' do
    it 'creates stack service with read_only and updates it properly' do
      with_fixture_dir("stack/read_only") do
        run! 'kontena stack install redis.yml'
      end
      k = run! 'kontena service show simple/redis'
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
        run! 'kontena stack install'
      end
      k = run! 'kontena stack ls -q'
      expect(k.out.split(/[\r\n]/)).to match array_including('twemproxy', 'twemproxy-redis_from_registry', 'twemproxy-redis_from_yml')
    end

    it 'does not mutate the $STACK variable' do
      with_fixture_dir("stack/depends") do
        k = run! 'kontena stack install'
      end
      k = run! 'kontena service show twemproxy/twemproxy'
      expect(k.out).to match(/STACKNAME=twemproxy[\r\n]/)
    end
  end

  context 'For a stack using service_instances resolver' do
    it 'interpolates the correct instance count' do
      with_fixture_dir("stack/service_instances_resolver") do
        run! 'kontena stack install'
        run! 'kontena service scale simple/redis 2'
        run! 'kontena stack upgrade simple'
        k = run! 'kontena service show simple/redis'
        expect(k.out).to match(/INSTANCE_COUNT=2[\r\n]/)
      end
    end
  end

  context 'For a stack with version requirement' do
    context 'When the requirement is matched' do
      it 'installs normally' do
        with_fixture_dir("stack/metadata") do
          run! 'kontena stack install -n simple --no-deploy'
        end
      end
    end

    context 'When the requirement is not matched' do
      it 'prompts for confirmation' do
        with_fixture_dir("stack/metadata") do
          k = kommando 'kontena stack install -n simple --no-deploy future.yml', timeout: 20
          k.out.on "you sure" do
            k.in << "y\r"
          end
          k.run
          expect(k.code).to eq(0)
        end
        k = run! 'kontena stack show simple'
        expect(k.out).to match /^\s+metadata:/
        expect(k.out).to match /^\s+required_kontena_version:/
      end

      it 'installs if --force is used' do
        with_fixture_dir("stack/metadata") do
          k = run!  'kontena stack install --force -n simple --no-deploy future.yml', timeout: 20
          expect(k.out).to match /Warning.*version/
        end
        k = run! 'kontena stack show simple'
        expect(k.out).to match /^\s+metadata:/
        expect(k.out).to match /^\s+required_kontena_version:/
      end
    end
  end
end
