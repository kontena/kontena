require 'spec_helper'

describe 'stack upgrade' do
  context 'from file' do
    before(:each) do
      with_fixture_dir("stack/upgrade") do
        k = run 'kontena stack install version1.yml'
        expect(k.code).to eq(0)
      end
    end

    after(:each) do
      run 'kontena stack rm --force redis'
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
        expect(k.out).to match /Replacing stack.*Are you sure\?.*Aborted command/m
      end
    end
  end

  context "for a stack that is linked to externally" do
    before(:each) do
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
        k = run 'kontena stack upgrade --no-deploy links-external-linked external-linked_2.yml'
        expect(k.code).to_not eq(0), k.out
        expect(k.out).to match /Cannot delete service that is linked to another service/
      end
    end

    it 'fails to deploy if linked' do
      with_fixture_dir("stack/links") do
        k = run 'kontena stack upgrade --no-deploy links-external-linked external-linked_2.yml'
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
      run 'kontena stack ls -q|grep twemproxy|xargs -n1 kontena stack rm --force'
    end

    context "when a new dependency is added" do
      it 'installs the added stack' do
        with_fixture_dir("stack/depends") do
          run 'kontena stack install'
        end

        with_fixture_dir("stack/depends/monitor_added") do
          k = run 'kontena stack upgrade --force'
          expect(k.code).to eq (0)
        end

        k = run 'kontena stack ls -q'
        expect(k.out).to match /^twemproxy-redis_from_yml-monitor$/m
      end
    end

    context "when a dependency is removed" do
      it 'removes the stack' do
        with_fixture_dir("stack/depends/monitor_added") do
          run 'kontena stack install'
        end

        k = run 'kontena stack ls -q'
        expect(k.out).to match /^twemproxy-redis_from_yml-monitor$/m

        with_fixture_dir("stack/depends/monitor_removed") do
          k = run 'kontena stack upgrade --force'
          expect(k.code).to eq (0)
        end

        k = run 'kontena stack ls -q'
        expect(k.out).not_to match /^twemproxy-redis_from_yml-monitor$/m
      end
    end

    context "when a dependency is replaced" do
      it 'removes the stack' do
        with_fixture_dir("stack/depends") do
          run 'kontena stack install'
        end

        k = run 'kontena stack show twemproxy-redis_from_yml'
        expect(k.out).to match /^stack: test\/redis/m

        with_fixture_dir("stack/depends/second_redis_replaced") do
          k = run 'kontena stack upgrade --force'
          expect(k.code).to eq (0)
        end

        k = run 'kontena stack show twemproxy-redis_from_yml'
        expect(k.out).to match /^stack: kontena\/redis/m
      end
    end
  end
end
