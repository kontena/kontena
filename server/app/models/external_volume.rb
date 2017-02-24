class ExternalVolume
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String
  
  has_one :volume
end
