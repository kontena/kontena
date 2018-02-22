require 'spec_helper'

describe 'app subcommand' do
  context 'with the app-command plugin', subcommand: :app do
    describe 'app ps', subcommand: :app do
      it "returns list" do
        with_fixture_dir('app/simple') do
          k = run!('kontena app ps')
          %w(lb nginx redis).each do |service|
            expect(k.out).to match(/#{service}/)
          end
        end
      end
    end
  end
end
