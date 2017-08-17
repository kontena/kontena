require 'spec_helper'

describe 'app subcommand' do
  context 'with the app-command plugin', subcommand: :app do
    describe 'app remove', subcommand: :app do
      it 'removes a deployed app' do
        with_fixture_dir('app/simple') do
          k = run('kontena app deploy')
          k = run('kontena app rm --force')
          expect(k.code).to eq(0)
          sleep 1
          k = run('kontena service ls')
          expect(k.code).to eq(0)
          %w(lb nginx redis).each do |service|
            expect(k.out).not_to match(/simple-#{service}/)
          end
        end
      end
    end
  end
end
