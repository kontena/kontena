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
end
