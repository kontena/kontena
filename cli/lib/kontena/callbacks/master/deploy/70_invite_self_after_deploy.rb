module Kontena
  module Callbacks
    class InviteSelfAfterDeploy < Kontena::Callback

      include Kontena::Cli::Common

      matches_commands 'master create'

      def cloud_user_data
        return @cloud_user_data if @cloud_user_data
        return nil unless cloud_auth?
        user_data = {}
        response = nil
        spinner "Retrieving user information from Kontena Cloud" do
          response = cloud_client.get(kontena_account.userinfo_endpoint)
        end
        if response && response.kind_of?(Hash) && response.has_key?('data') && response['data'].has_key?('attributes')
          user_data[:email] = response['data']['attributes']['email']
          user_data[:username] = response['data']['attributes']['username']
          user_data[:id] = response['data']['id']
          user_data[:verified] = response['data']['attributes']['verified']
          @cloud_user_data = user_data
        end
        @cloud_user_data
      end

      def after
        return unless current_master
        return unless command.exit_code == 0
        return unless current_master.username.to_s == 'admin'
        return nil if command.skip_auth_provider?
        return nil unless cloud_user_data

        invite_response = nil
        spinner "Creating user #{cloud_user_data[:email]} into Kontena Master" do |spin|
          invite_response = Kontena.run("master users invite --external-id #{cloud_user_data[:id]} --return #{cloud_user_data[:email].shellescape}", returning: :result)
          unless invite_response.kind_of?(Hash) && invite_response.has_key?('invite_code')
            spin.fail
          end
        end

        return nil unless invite_response
        ENV["DEBUG"] && puts("Got invite code: #{invite_response['invite_code']}")

        role_status = nil

        spinner "Adding master_admin role for #{cloud_user_data[:email]}" do |spin|
          role_status = Kontena.run("master users role add --silent master_admin #{cloud_user_data[:email].shellescape}")
          spin.fail if role_status.to_i > 0
        end

        return nil if role_status.to_i > 0

        spinner "Adding #{cloud_user_data[:email]} to grid 'test'" do |spin|
          grid_add_status = Kontena.run("grid user add --grid test #{cloud_user_data[:email].shellescape}")
          spin.fail if grid_add_status.to_i > 0
        end

        new_user_token = nil
        spinner "Creating an access token for #{cloud_user_data[:email]}" do |spin|
          new_user_token = Kontena.run("master token create -e 0 -s user --return -u #{cloud_user_data[:email].shellescape}", returning: :result)
        end

        master_name = current_master.name.dup
        master_url  = current_master.url
        old_master  = current_master

        spinner "Copying server '#{current_master.name}' to '#{current_master.name}-admin' in configuration" do
          config.servers << Kontena::Cli::Config::Server.new(
            name: "#{current_master.name}-admin",
            url: current_master.url,
            username: 'admin',
            grid: current_master.grid,
            token: Kontena::Cli::Config::Token.new(
              access_token:  current_master.token.access_token,
              refresh_token: current_master.token.refresh_token,
              expires_at:    current_master.token.expires_at,
              parent_type:   :master,
              parent_name:   "#{current_master.name}-admin"
            ),
            account: 'master'
          )
        end

        spinner "Authenticating as #{cloud_user_data[:email]} to Kontena Master '#{current_master.name}'" do
          current_master.token = Kontena::Cli::Config::Token.new(
            access_token:  new_user_token[:access_token],
            refresh_token: new_user_token[:refresh_token],
            expires_at:    new_user_token[:expires_in].to_i > 0 ? Time.now.utc.to_i + new_user_token[:expires_in].to_i : nil,
            parent_type:   :master,
            parent_name:   "#{current_master.name}"
          )
          current_master.username = new_user_token[:user_name].to_s == "" ? new_user_token[:user_email] : new_user_token[:user_name]
          config.write
        end
      end
    end
  end
end
