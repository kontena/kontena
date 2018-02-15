require 'kontena/cli/master/token_command'
require 'kontena/cli/master/token/show_command'

describe Kontena::Cli::Master::Token::ShowCommand do

  include ClientHelpers
  include RequirementsHelper
  include OutputHelpers

  expect_to_require_current_master
  expect_to_require_current_master_token

  context 'for an access token' do
    let(:response) do
      {
        "id" => "123",
        "token_type" => "bearer",
        "access_token" => nil,
        "refresh_token" => nil,
        "access_token_last_four" => "abcd",
        "refresh_token_last_four" => "efgh",
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

    it 'requests token data from master and displays it' do
      expect(client).to receive(:get).with("/oauth2/tokens/123").and_return(response)
      expect{subject.run(['123'])}.to output_yaml(
        123 => {
          'token_type' => 'bearer',
          'scopes' => 'user',
          'user_id' => 'abc',
          'user_email' => 'user@email',
          'user_name' => 'username',
          'server_name' => 'foo',
          'access_token_last_four' => 'abcd',
          'refresh_token_last_four' => 'efgh',
          'expires_in' => 100,
          'description' => 'description test'
        }
      )
    end
  end

  context 'for an authorization code' do
    let(:response) do
      {
        "id" => 123,
        "grant_type" => "authorization_code",
        "code" => "abcd",
        "scopes" => "user",
        "user" => {
          "id" => "abc",
          "email" => "user@email",
          "name" => "username"
        },
        "server" => {
          "name" => "foo"
        },
        "description" => 'description test'
      }
    end

    it 'requests auth code data from master and displays it' do
      expect(client).to receive(:get).with("/oauth2/tokens/123").and_return(response)
      expect{subject.run(['123'])}.to output_yaml(
        123 => {
          'code' => 'abcd',
          'token_type' => 'authorization_code',
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
