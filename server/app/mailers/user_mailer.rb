class UserMailer < ActionMailer::Base
  layout 'mailer'
  default from: 'noreply@kontena.io'

  before_action :default_variables

  ##
  # @param [String] user_id
  def verify_email(user_id)
    @user = User.find(user_id)
    return unless @user
    @verify_url = "#{@site_url}/verify_email?token=#{@user.confirm_token}"
    mail(to: @user.email, subject: 'Verify your Kontena account').deliver
  end

  ##
  # @param [String] user_id
  def welcome_email(user_id)
    @user = User.find(user_id)
    return unless @user
    @url = "#{@site_url}/login"
    mail(to: @user.email, subject: "Welcome to #{@site_name}") do |format|
      format.html
      format.text
    end.deliver
  end

  def password_reset_email(user_id)
    @user = User.find(user_id)
    return unless @user

    @url = "#{@site_url}/password_reset?token=#{@user.password_reset_token}"
    mail(to: @user.email, subject: 'Password reset request').deliver
  end

  private

  def default_variables
    @site_url = 'https://kontena.io'
    @site_name = 'Kontena'
  end
end