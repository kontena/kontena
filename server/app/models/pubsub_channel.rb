class PubsubChannel
  include Mongoid::Document

  field :created_at, type: DateTime
  field :channel, type: String
  field :data, type: BSON::Binary
end
