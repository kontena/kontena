module CurrentUser
  def current_user_id
    if self.current_access_token
      @current_user_id = self.current_access_token.user_id
    end

    @current_user_id
  end

  ##
  # @return [User]
  def current_user
    @current_user ||= User.find_by(_id: self.current_user_id) if self.current_user_id
  end

  def require_current_user
    if current_user.nil?
      halt_request(403, {error: 'Access denied'})
    end
  end
end
