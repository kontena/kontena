require_relative "../../spec_helper"
require "kontena/cli/register_command"

describe Kontena::Cli::RegisterCommand do
  describe '#register' do

    let(:auth_client) do
      double(Kontena::Client)
    end

    let(:subject) { described_class.new(File.basename($0)) }

    it 'asks password twice' do
      allow(subject).to receive(:ask).once.with('Email: ').and_return('john.doe@acme.io')
      expect(subject).to receive(:password).once.with('Password: ').and_return('secret')
      expect(subject).to receive(:password).once.with('Password again: ').and_return('secret')
      allow(Kontena::Client).to receive(:new).and_return(auth_client)
      allow(auth_client).to receive(:post)
      subject.run([])
    end

    it 'validates given passwords' do
      allow(subject).to receive(:ask).once.with('Email: ').and_return('john.doe@acme.io')
      expect(subject).to receive(:password).once.with('Password: ').and_return('secret')
      expect(subject).to receive(:password).once.with('Password again: ').and_return('secret2')
      expect{subject.run([])}.to raise_error(SystemExit)
    end

    it 'uses https://auth.kontena.io as default auth provider' do
      allow(subject).to receive(:ask).and_return('john.doe@acme.io')
      allow(subject).to receive(:ask).once.with('Email: ').and_return('john.doe@acme.io')
      expect(subject).to receive(:password).once.with('Password: ').and_return('secret')
      expect(subject).to receive(:password).once.with('Password again: ').and_return('secret')
      expect(Kontena::Client).to receive(:new).with('https://auth.kontena.io').and_return(auth_client)
      allow(auth_client).to receive(:post)
      subject.run([])
    end

    it 'uses given auth provider' do
      allow(subject).to receive(:ask).and_return('john.doe@acme.io')
      expect(subject).to receive(:password).once.with('Password: ').and_return('secret')
      expect(subject).to receive(:password).once.with('Password again: ').and_return('secret')
      expect(Kontena::Client).to receive(:new).with('http://custom.auth-provider.io').and_return(auth_client)
      allow(auth_client).to receive(:post)
      subject.run(['--auth-provider-url', 'http://custom.auth-provider.io'])
    end

    it 'sends register request to auth provider' do
      allow(subject).to receive(:ask).and_return('john.doe@acme.io')
      expect(subject).to receive(:password).once.with('Password: ').and_return('secret')
      expect(subject).to receive(:password).once.with('Password again: ').and_return('secret')
      allow(Kontena::Client).to receive(:new).with('https://auth.kontena.io').and_return(auth_client)
      expect(auth_client).to receive(:post).with('users', {email: 'john.doe@acme.io', password: 'secret'})
      subject.run([])
    end
  end
end
