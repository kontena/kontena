require 'spec_helper'

describe 'app commands' do
  context 'ps' do
    it "returns list" do
      Dir.chdir('./spec/fixtures/app/simple/') do
        k = run('kontena app ps')
        expect(k.code).to eq(0)
        %w(lb nginx redis).each do |service|
          expect(k.out).to match(/#{service}/)
        end
      end
    end
  end

  context 'deploy' do
    it 'deploys a simple stack' do
      Dir.chdir('./spec/fixtures/app/simple/') do
        k = run('kontena app deploy')
        k.wait
        expect(k.code).to eq(0)
        k = run('kontena service ls')
        expect(k.code).to eq(0)
        %w(lb nginx redis).each do |service|
          expect(k.out).to match(/simple-#{service}/)
        end
        run('kontena app rm --force')
      end
    end
  end

  context 'rm' do
    it 'removes a deployed stack' do
      Dir.chdir('./spec/fixtures/app/simple/') do
        k = run('kontena app deploy')
        k.wait
        k = run('kontena app rm --force')
        k.wait
        expect(k.code).to eq(0)
        k = run('kontena service ls')
        expect(k.code).to eq(0)
        %w(lb nginx redis).each do |service|
          expect(k.out).not_to match(/simple-#{service}/)
        end
      end
    end
  end
end
