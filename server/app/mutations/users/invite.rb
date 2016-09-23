module Users
  class Invite < Mutations::Command
    required do
      model :user
    end

    optional do
      string :email, matches: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i
      string :name
      string :external_id
    end

    def validate
      unless self.user.can_create?(User)
        add_error(:user, :forbidden, 'Operation not allowed')
      end
    end

    def execute
      query = []
      query << { external_id: self.external_id } if self.external_id
      query << { name: self.name }               if self.name
      query << { email: self.email }             if self.email

      unless query.empty?
        end_user = User.or(*query).first
      end

      end_user ||= User.new(
        external_id: self.external_id,
        name:        self.name,
        email:       self.email
      )

      end_user.with_invite = true

      if end_user.errors.size > 0
        end_user.errors.each do |key, message|
          add_error(key, :invalid, message)
        end
        return
      elsif !end_user.save
        add_error('user', :error, 'Unable to save user')
        return
      end

      end_user
    end
  end
end
