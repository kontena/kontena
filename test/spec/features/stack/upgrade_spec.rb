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
end
