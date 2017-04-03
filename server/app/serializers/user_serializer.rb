class UserSerializer < KontenaJsonSerializer

  attribute :id
  attribute :email
  attribute :name
  attribute :roles

  def id
    object.id.to_s
  end

  def roles
    object.roles.map {|r| { name: r.name, description: r.description }}
  end
end
