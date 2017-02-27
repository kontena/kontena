require_relative "../../../spec_helper"
require 'kontena/cli/cloud/login_command'
require 'kontena/cli/localhost_web_server'
require 'launchy'

describe Kontena::Cli::Cloud::LoginCommand do

  include ClientHelpers

  let(:subject) do
    described_class.new(File.basename($0))
  end

  let(:config) { double(:config) }
  let(:client) { double(:client) }

  before(:each) do
    allow(subject).to receive(:config).and_return(config)
    allow(Kontena::Client).to receive(:new).and_return(client)
    allow(Kontena).to receive(:browserless?).and_return(false)
  end

  it 'should give error if trying to use --code and --force' do
    expect(subject).to receive(:exit_with_error).and_throw(:exit_with_error)
    subject.run(['--code', 'abcd', '--force'])
  end

  it 'should give error if trying to use --token and --force' do
    expect(subject).to receive(:exit_with_error).and_throw(:exit_with_error)
    subject.run(['--token', 'abcd', '--force'])
  end

  it 'should give error if trying to use --token and --code' do
    expect(subject).to receive(:exit_with_error).and_throw(:exit_with_error)
    subject.run(['--token', 'abcd', '--code', 'defg'])
  end

  context 'when config has token' do
    let(:account) do
      account = Kontena::Cli::Config::Account.new(Kontena::Cli::Config.kontena_account_data)
      account.token = Kontena::Cli::Config::Token.new(access_token: 'foofoo', parent_type: :account, parent_name: 'kontena')
      account.username = 'testuser'
      account
    end

    before(:each) do
      expect(subject).to receive(:kontena_account).at_least(:once).and_return(account)
    end

    it 'should check if the token works and not authenticate again if it does' do
      expect(client).to receive(:authentication_ok?).with(account.userinfo_endpoint).and_return(true)
      expect(subject).to receive(:finish).and_return(true)
      subject.run([])
    end

    it 'should not use the token from config when --token given' do
      expect(client).to receive(:authentication_ok?).with(account.userinfo_endpoint).and_return(true)
      expect(subject).to receive(:finish).and_return(true)
      subject.run(['--token', 'abcd'])
      expect(account.token.access_token).to eq 'abcd'
    end

    it 'should not use the token from config when --code given' do
      expect(client).to receive(:authentication_ok?).with(account.userinfo_endpoint).and_return(true)
      expect(subject).to receive(:use_authorization_code).with('abcd')
      expect(subject).not_to receive(:web_flow)
      expect(subject).to receive(:finish).and_return(true)
      subject.run(['--code', 'abcd'])
    end

    it 'should not use the token from config when --force given' do
      expect(client).not_to receive(:authentication_ok?)
      expect(subject).to receive(:web_flow).and_return(true)
      expect(subject).to receive(:finish).and_return(true)
      subject.run(['--force'])
    end
  end

  context 'when config does not have a token' do
    let(:account) do
      account = Kontena::Cli::Config::Account.new(Kontena::Cli::Config.kontena_account_data)
      account.token = Kontena::Cli::Config::Token.new(access_token: nil, parent_type: :account, parent_name: 'kontena')
      account.username = 'testuser'
      account
    end

    before(:each) do
      expect(subject).to receive(:kontena_account).at_least(:once).and_return(account)
    end

    it 'should use --code if given' do
      expect(client).to receive(:authentication_ok?).with(account.userinfo_endpoint).and_return(true)
      expect(client).to receive(:exchange_code).with('abcd').and_return({
        'access_token' => 'abcdefg'
      })
      expect(subject).not_to receive(:web_flow)
      expect(subject).to receive(:finish).and_return(true)
      subject.run(['--code', 'abcd'])
      expect(account.token.access_token).to eq 'abcdefg'
    end

    it 'should use the --token if given' do
      expect(client).to receive(:authentication_ok?).with(account.userinfo_endpoint).and_return(true)
      expect(subject).to receive(:finish).and_return(true)
      subject.run(['--token', 'abcd'])
      expect(account.token.access_token).to eq 'abcd'
    end

    it 'should enter the webflow if --force given' do
      expect(client).not_to receive(:authentication_ok?)
      expect(subject).to receive(:web_flow).and_return(true)
      expect(subject).to receive(:finish).and_return(true)
      subject.run(['--force'])
    end

    it 'should enter the webflow if --force not given' do
      expect(client).not_to receive(:authentication_ok?)
      expect(subject).to receive(:web_flow).and_return(true)
      expect(subject).to receive(:finish).and_return(true)
      subject.run([])
    end
  end

  context 'when performing web flow' do
    let(:account) do
      account = Kontena::Cli::Config::Account.new(Kontena::Cli::Config.kontena_account_data)
      account.token = Kontena::Cli::Config::Token.new(access_token: nil, parent_type: :account, parent_name: 'kontena')
      account
    end

    let(:webserver) { double(:webserver) }

    before(:each) do
      expect(subject).to receive(:kontena_account).at_least(:once).and_return(account)
      allow(subject).to receive(:any_key_to_continue).and_return(true)
    end

    context 'cloud returns a token' do
      it 'starts a web server, opens a a browser, parses the response and updates the token' do
        expect(Kontena::LocalhostWebServer).to receive(:new).and_return(webserver)
        expect(webserver).to receive(:port).and_return(1234)
        expect(webserver).to receive(:serve_one).and_return({
          'access_token' => 'abcd'
        })
        expect(Launchy).to receive(:open).and_return(true)
        expect(subject).to receive(:finish).and_return(true)
        subject.run([])
        expect(account.token.access_token).to eq 'abcd'
      end
    end

    context 'cloud returns a code' do
      it 'starts a web server, opens a a browser, parses the response and updates the token' do
        expect(Kontena::LocalhostWebServer).to receive(:new).and_return(webserver)
        expect(webserver).to receive(:port).and_return(1234)
        expect(webserver).to receive(:serve_one).and_return({
          'code' => 'abcd'
        })
        expect(Launchy).to receive(:open).and_return(true)
        expect(client).to receive(:exchange_code).with('abcd').and_return({
          'access_token' => 'abcdefg'
        })
        expect(subject).to receive(:finish).and_return(true)
        subject.run([])
        expect(account.token.access_token).to eq 'abcdefg'
      end
    end

    context 'cloud returns an error' do
      it 'starts a web server, opens a a browser, parses the response and updates the token' do
        expect(Kontena::LocalhostWebServer).to receive(:new).and_return(webserver)
        expect(webserver).to receive(:port).and_return(1234)
        expect(webserver).to receive(:serve_one).and_return({
          'error' => 'foo'
        })
        expect(Launchy).to receive(:open).and_return(true)
        expect(subject).to receive(:exit_with_error).and_throw(:exit_with_error)
        subject.run([])
      end
    end
  end

  context 'methods' do
    let(:account) do
      account = Kontena::Cli::Config::Account.new(Kontena::Cli::Config.kontena_account_data)
      account.token = Kontena::Cli::Config::Token.new(access_token: 'foofoo', parent_type: :account, parent_name: 'kontena')
      account
    end

    before(:each) do
      allow(subject).to receive(:kontena_account).and_return(account)
    end

    describe '#finish' do
      it 'updates user info, sets the current account, writes the config and displays login info' do
        expect(subject).to receive(:kontena_account).at_least(:once).and_return(account)
        allow(config).to receive(:reset_instance).and_return(true)
        allow(config).to receive(:display_logo).and_return(true)
        allow(subject).to receive(:reset_cloud_client).and_return(true)
        expect(subject).to receive(:display_login_info).and_return(true)
        expect(subject).to receive(:update_userinfo).and_return(true)
        expect(config).to receive(:current_account=).and_return(true)
        expect(config).to receive(:write).and_return(true)
        subject.finish
      end
    end

    describe '#use_authorization_code' do
      it 'should use #exchange_code on client' do
        expect(client).to receive(:exchange_code).with('abcd').and_return(true)
        allow(subject).to receive(:update_token).and_return(true)
        subject.use_authorization_code('abcd')
      end

      it 'should update the account token' do
        expect(client).to receive(:exchange_code).with('abcd').and_return(
          'access_token' => 'token'
        )
        subject.use_authorization_code('abcd')
        expect(account.token.access_token).to eq 'token'
      end
    end

    describe '#update_userinfo' do
      it 'should make a get request to account userinfo endpoint' do
        expect(client).to receive(:get).with('/' + account.userinfo_endpoint.split('/').last).and_return(nil)
        allow(subject).to receive(:exit_with_error)
        subject.update_userinfo
      end

      it 'should update account username' do
        expect(client).to receive(:get).and_return(
          'data' => {
            'attributes' => {
              'username' => 'foofoo'
            }
          }
        )
        expect(account).to receive(:username=).with('foofoo')
        subject.update_userinfo
      end

      it 'should exit with error if cloud responds with error' do
        expect(client).to receive(:get).and_return('error' => 'foo')
        expect(subject).to receive(:exit_with_error).and_throw(:exit_with_error)
        subject.update_userinfo
      end

      it 'should exit with error if cloud responds with something silly' do
        expect(client).to receive(:get).and_return('foo')
        expect(subject).to receive(:exit_with_error).and_throw(:exit_with_error)
        subject.update_userinfo
      end
    end

    describe '#update_token' do
      it 'should exchange code if response has code' do
        expect(subject).to receive(:use_authorization_code).with('abcd').and_return({})
        subject.update_token({'code' => 'abcd'})
      end

      it 'should update the token of kontena account' do
        subject.update_token(
          'access_token' => 'token',
          'refresh_token' => 'refresh',
          'expires_in' => 123,
          'expires_at' => 12345
        )
        expect(account.token.access_token).to eq 'token'
        expect(account.token.refresh_token).to eq 'refresh'
        expect(account.token.expires_at).to eq 12345
      end

      it 'should give error when response has error' do
        expect(subject).to receive(:exit_with_error).and_throw(:exit_with_error)
        subject.update_token('error' => 'fail!')
      end

      it 'should raise if response is not a hash' do
        expect{subject.update_token('foo')}.to raise_error(TypeError)
      end
    end
  end
end
