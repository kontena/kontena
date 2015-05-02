require_relative '../../services/auth_service/client'

module Users
  class Register < Mutations::Command
    required do
      string :email, matches: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i
      string :password, min_length: 8
    end

    def execute
      if User.count == 0
        user = create_admin_user(email)
      else
        user = User.find_by(email: email)
        if user.nil?
          add_error(:email, :invalid, 'User not allowed to use this server.')
          return
        end
      end
      kontena_user = AuthService::Client.new.register({'email' => email, 'password' => password})
      if kontena_user.nil?
        add_error(:external_id, :invalid, 'User registering failed')
        return
      end

      user.update_attribute(:external_id, kontena_user['id'])

      user

    end

    ##
    # @param [Hash] kontena_user
    def create_admin_user(kontena_user)
      User.create(email: kontena_user['email'], external_id: kontena_user['id'])
    end
  end
end
