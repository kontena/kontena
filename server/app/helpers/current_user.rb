module CurrentUser
  def current_user_id
    current_user ? current_user.id : nil
  end

  ##
  # @return [User]
  def current_user
    @current_user ||= env["auth.current_user"]
  end

  def require_current_user
    if current_user.nil?
      halt_request(403, {error: 'Access denied'})
    end
  end
end
