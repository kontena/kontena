json.id user.id.to_s
json.email user.email
json.name user.name
json.roles user.roles.map {|r| { name: r.name, description: r.description }}