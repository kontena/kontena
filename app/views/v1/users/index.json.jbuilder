json.users @users do |user|
  json.partial! 'app/views/v1/users/user', user: user
end
