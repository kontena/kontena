require 'spec_helper'

describe 'stack upgrade' do
  context 'from file' do
    before(:each) do
      run 'kontena stack rm --force redis'
      run 'kontena stack rm --force links-external-linked'
      with_fixture_dir("stack/upgrade") do
        run 'kontena stack install version1.yml'
      end
    end

    after(:each) do
      run 'kontena stack rm --force redis'
      run 'kontena stack rm --force links-external-linked'
    end

    it 'upgrades a stack' do
      k = run 'kontena service show redis/redis'
      expect(k.code).to eq(0)
      expect(k.out).to match /image: redis:3.0.7-alpine/

      with_fixture_dir("stack/upgrade") do
        k = run 'kontena stack upgrade redis version2.yml'
        expect(k.code).to eq(0), k.out
      end

      k = run 'kontena service show redis/redis'
      expect(k.code).to eq(0)
      expect(k.out).to match /image: redis:3.2.8-alpine/
    end

    it 'prompts if the stack is different' do
      with_fixture_dir("stack/upgrade") do
        k = kommando 'kontena stack upgrade redis different.yml'
        k.out.on /Are you sure/ do
          k.in << "n\r"
        end
        k.run
        expect(k.code).to eq(1)
        expect(uncolorize(k.out)).to match /redis from test\/redis to test\/notredis.*Aborted command/m
      end
    end
  end

  context "for a stack that is linked to externally" do
    before(:each) do
      run 'kontena service rm --force external-linking-service'
      run 'kontena stack rm --force links-external-linked'
      with_fixture_dir("stack/links") do
        k = run 'kontena stack install external-linked_1.yml'
        expect(k.code).to eq(0), k.out
      end
    end

    after(:each) do
      run 'kontena service rm --force external-linking-service'
      run 'kontena stack rm --force links-external-linked'
    end

    it 'fails to upgrade if linked' do
      k = run 'kontena service create --link links-external-linked/bar external-linking-service redis'
      expect(k.code).to eq(0), k.out

      with_fixture_dir("stack/links") do
        k = run 'kontena stack upgrade --force --no-deploy links-external-linked external-linked_2.yml'
        expect(k.code).to_not eq(0), k.out
        expect(k.out).to match /Cannot delete service that is linked to another service/
      end
    end

    it 'fails to deploy if linked' do
      with_fixture_dir("stack/links") do
        k = run 'kontena stack upgrade --force --no-deploy links-external-linked external-linked_2.yml'
        expect(k.code).to eq(0), k.out
      end

      k = run 'kontena service create --link links-external-linked/bar external-linking-service redis'
      expect(k.code).to eq(0), k.out

      with_fixture_dir("stack/links") do
        k = run 'kontena stack deploy links-external-linked'
        expect(k.code).to_not eq(0), k.out
        expect(k.out).to match /deploy failed/
      end
    end
  end

  context "for a stack that has dependencies" do
    after do
      run('kontena stack ls -q').out.split(/[\r\n]/).each do |stack|
        next unless stack.start_with?('twemproxy')
        run "kontena stack rm --force #{stack}"
      end
    end

    context "when a new dependency is added" do
      it 'installs the added stack' do
        with_fixture_dir("stack/depends") do
          run 'kontena stack install'
        end

        with_fixture_dir("stack/depends/monitor_added") do
          k = run 'kontena stack upgrade --force twemproxy'
          puts k.out unless k.code.zero?
          expect(k.code).to eq (0)
        end

        k = run 'kontena stack ls -q'
        expect(k.out).to match /twemproxy-redis_from_yml-monitor/
      end
    end

    context "when a dependency is removed" do
      it 'removes the stack' do
        with_fixture_dir("stack/depends/monitor_added") do
          run 'kontena stack install'
        end

        k = run 'kontena stack ls -q'
        expect(k.out).to match /twemproxy-redis_from_yml-monitor/

        with_fixture_dir("stack/depends/monitor_removed") do
          k = run 'kontena stack upgrade --force twemproxy'
          puts k.out unless k.code.zero?
          expect(k.code).to eq (0)
        end

        k = run 'kontena stack ls -q'
        expect(k.out).not_to match /twemproxy-redis_from_yml-monitor/
      end
    end

    context "when a dependency is replaced" do
      it 'removes the stack' do
        with_fixture_dir("stack/depends") do
          run 'kontena stack install'
        end

        k = run 'kontena stack show twemproxy-redis_from_yml'
        expect(k.out).to match /stack: test\/redis/

        with_fixture_dir("stack/depends/second_redis_replaced") do
          k = run 'kontena stack upgrade --force twemproxy'
          puts k.out unless k.code.zero?
          expect(k.code).to eq (0)
        end

        k = run 'kontena stack show twemproxy-redis_from_yml'
        expect(k.out).to match /stack: kontena\/redis/
      end
    end
  end
end
