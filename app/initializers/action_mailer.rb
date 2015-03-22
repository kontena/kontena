require 'action_mailer'

ActionMailer::Base.delivery_method = :smtp
ActionMailer::Base.raise_delivery_errors = true
ActionMailer::Base.smtp_settings = {
    :address        => 'smtp.mandrillapp.com',
    :port           => '587',
    :authentication => :plain,
    :user_name      => ENV['MANDRILL_USERNAME'],
    :password       => ENV['MANDRILL_PASSWORD'],
    :domain         => 'kontena.io',
    :enable_starttls_auto => true
}
ActionMailer::Base.view_paths = File.expand_path('app/views')