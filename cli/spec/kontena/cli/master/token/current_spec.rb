require 'kontena/cli/master/token_command'
require 'kontena/cli/master/token/current_command'

describe Kontena::Cli::Master::Token::CurrentCommand do

  include ClientHelpers
  include RequirementsHelper

  expect_to_require_current_master
  expect_to_require_current_master_token

  let(:master) { double(token: double(access_token: 'foo', refresh_token: 'bar', expires_at: Time.now.utc.to_i + 999)) }

  before do
    allow(subject).to receive(:current_master).and_return(master)
  end

  it 'runs master token show with the current token' do
    expect(Kontena).to receive(:run!).with(['master', 'token', 'show', 'foo'])
    subject.execute
  end

  describe '--token' do
    it 'outputs the current access token' do
      expect{subject.run(['--token'])}.to output(/\Afoo\Z/).to_stdout
    end
  end

  describe '--refresh-token' do
    it 'outputs the current refresh token' do
      expect{subject.run(['--refresh-token'])}.to output(/\Abar\Z/).to_stdout
    end
  end

  describe 'expires-in' do
    it 'reports time until token expiration' do
      expect{subject.run(['--expires-in'])}.to output(/\A[0-9]{3}\Z/).to_stdout
    end
  end
end
