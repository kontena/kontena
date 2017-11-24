require 'spec_helper'

describe 'app subcommand' do
  context 'with the app-command plugin', subcommand: :app do
    describe 'app deploy' do
      it 'deploys a simple app' do
        with_fixture_dir('app/simple') do
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
  end
end
