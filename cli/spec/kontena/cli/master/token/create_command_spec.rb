require 'kontena/cli/master/token_command'
require 'kontena/cli/master/token/create_command'

describe Kontena::Cli::Master::Token::CreateCommand do
  include ClientHelpers
  include RequirementsHelper
  include OutputHelpers

  expect_to_require_current_master
  expect_to_require_current_master_token

  let(:response) do
    {
      "id" => "123",
      "token_type" => "bearer",
      "access_token" => '1234abcd',
      "refresh_token" => '2345defg',
      "access_token_last_four" => "abcd",
      "refresh_token_last_four" => "defg",
      "expires_in" => 100,
      "scopes" => "user",
      "user" => {
        "id" => "abc",
        "email" => "user@email",
        "name" => "username"
      },
      "server" => {
        "name" => "foo"
      },
      "description" => "description test"
    }
  end

  context '--description' do
    it 'adds a description to token create request' do
      expect(client).to receive(:post) do |path, data|
        expect(path).to eq '/oauth2/authorize'
        expect(data[:description]).to eq 'description test'
      end.and_return(response)
      expect{subject.run(['--description', 'description test'])}.not_to exit_with_error
    end
  end

  context '--scopes' do
    it 'accepts a comma separated list of scopes' do
      expect(client).to receive(:post) do |path, data|
        expect(path).to eq '/oauth2/authorize'
        expect(data[:scope]).to eq 'xyz,zyx'
      end.and_return(response)
      expect{subject.run(['--scopes', 'xyz,zyx'])}.not_to exit_with_error
    end
  end

  context '--code' do
    it 'can request an authorization_code' do
      expect(client).to receive(:post) do |path, data|
        expect(path).to eq '/oauth2/authorize'
        expect(data[:response_type]).to eq 'code'
      end.and_return(response)
      expect{subject.run(['--code'])}.not_to exit_with_error
    end
  end

  context '--expires-in' do
    it 'can request a token without expiration' do
      expect(client).to receive(:post) do |path, data|
        expect(path).to eq '/oauth2/authorize'
        expect(data[:expires_in]).to eq '0'
      end.and_return(response)
      expect{subject.run(['--expires-in', '0'])}.not_to exit_with_error
    end
  end

  context '--token' do
    it 'requests a token and outputs the generated token' do
      expect(client).to receive(:post) do |path, data|
        expect(path).to eq '/oauth2/authorize'
        expect(data[:response_type]).to eq 'token'
      end.and_return(response)
      expect{subject.run(['--token'])}.to output(/\A1234abcd\Z/).to_stdout
    end
  end

  context '--id' do
    it 'requests a token and outputs the generated token id' do
      expect(client).to receive(:post) do |path, data|
        expect(path).to eq '/oauth2/authorize'
        expect(data[:response_type]).to eq 'token'
      end.and_return(response)
      expect{subject.run(['--id'])}.to output(/\A123\Z/).to_stdout
    end
  end

  context '--user' do
    it 'can request a token for another user' do
      expect(client).to receive(:post) do |path, data|
        expect(path).to eq '/oauth2/authorize'
        expect(data[:user]).to eq 'foo@example.com'
      end.and_return(response)
      expect{subject.run(['--user', 'foo@example.com'])}.not_to exit_with_error
    end
  end

  context 'no parameters' do
    it 'requests an expiring user scoped token with an empty description and outputs token and refresh token' do
      expect(client).to receive(:post) do |path, data|
        expect(path).to eq '/oauth2/authorize'
        expect(data[:user]).to be_nil
        expect(data[:description]).to be_nil
        expect(data[:response_type]).to eq 'token'
        expect(data[:expires_in]).to eq '7200'
        expect(data[:scope]).to eq 'user'
      end.and_return(response)
      expect{subject.run([])}.to output_yaml(
        123 => {
          'access_token' => '1234abcd',
          'refresh_token' => '2345defg',
          'access_token_last_four' => 'abcd',
          'refresh_token_last_four' => 'defg',
          'expires_in' => 100,
          'token_type' => 'bearer',
          'scopes' => 'user',
          'user_id' => 'abc',
          'user_email' => 'user@email',
          'user_name' => 'username',
          'server_name' => 'foo',
          'description' => 'description test'
        }
      )
    end
  end
end
