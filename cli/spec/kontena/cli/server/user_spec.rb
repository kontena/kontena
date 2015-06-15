require_relative "../../../spec_helper"
require "kontena/cli/server/user"

module Kontena::Cli::Server
  describe User do
    describe '#register' do

      let(:auth_client) do
        double(Kontena::Client)
      end

      it 'asks email' do
        expect(subject).to receive(:ask).once.and_return('john.doe@acme.io')
        allow(subject).to receive(:password).and_return('secret')
        allow(Kontena::Client).to receive(:new).and_return(auth_client)
        allow(auth_client).to receive(:post)
        subject.register(nil, {})
      end

      it 'asks password twice' do
        allow(subject).to receive(:ask).once.and_return('john.doe@acme.io')
        expect(subject).to receive(:password).twice.and_return('secret')
        allow(Kontena::Client).to receive(:new).and_return(auth_client)
        allow(auth_client).to receive(:post)
        subject.register(nil, {})
      end

      it 'validates given passwords' do
        allow(subject).to receive(:ask).once.and_return('john.doe@acme.io')
        expect(subject).to receive(:password).twice.and_return('secret', 'secret2')
        expect{subject.register(nil, {})}.to raise_error(ArgumentError)
      end

      it 'uses https://auth.kontena.io as default auth provider' do
        allow(subject).to receive(:ask).and_return('john.doe@acme.io')
        allow(subject).to receive(:password).and_return('secret')
        expect(Kontena::Client).to receive(:new).with('https://auth.kontena.io').and_return(auth_client)
        allow(auth_client).to receive(:post)
        subject.register(nil, {})
      end

      it 'uses given auth provider' do
        allow(subject).to receive(:ask).and_return('john.doe@acme.io')
        allow(subject).to receive(:password).and_return('secret')
        expect(Kontena::Client).to receive(:new).with('http://custom.auth-provider.io').and_return(auth_client)
        allow(auth_client).to receive(:post)
        subject.register('http://custom.auth-provider.io', {})
      end

      it 'sends register request to auth provider' do
        allow(subject).to receive(:ask).and_return('john.doe@acme.io')
        allow(subject).to receive(:password).and_return('secret')
        allow(Kontena::Client).to receive(:new).with('https://auth.kontena.io').and_return(auth_client)
        expect(auth_client).to receive(:post).with('users', {email: 'john.doe@acme.io', password: 'secret'})
        subject.register(nil, {})
      end
    end
  end
end