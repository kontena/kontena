require 'spec_helper'

describe 'app subcommand' do
  context 'with the app-command plugin', subcommand: :app do
    describe 'app deploy' do
      it 'deploys a simple app' do
        with_fixture_dir('app/simple') do
          k = run('kontena app deploy')
          k.wait
          expect(k.code).to eq(0)
          
          # hack to ensure that the app services get cleaned up before the next spec runs
          run! 'kontena service update --stop-timeout=1s simple-lb'
          run! 'kontena service deploy --force simple-lb'

          k = run!('kontena service ls')
          %w(lb nginx redis).each do |service|
            expect(k.out).to match(/simple-#{service}/)
          end
          run!('kontena app rm --force')
        end
      end
    end
  end
end
