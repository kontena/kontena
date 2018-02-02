require 'spec_helper'

describe 'app subcommand' do
  context 'with the app-command plugin', subcommand: :app do
    describe 'app remove', subcommand: :app do
      it 'removes a deployed app' do
        with_fixture_dir('app/simple') do
          run!('kontena app deploy')
          run!('kontena app rm --force')
          sleep 1
          k = run!('kontena service ls')
          %w(lb nginx redis).each do |service|
            expect(k.out).not_to match(/simple-#{service}/)
          end
        end
      end
    end
  end
end
