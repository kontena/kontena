# Table for storing temporary random state strings
#
# A matching state must be found when receiving authorization
# callbacks to prevent fake authentication.
#
# The user relation is optional.
#
# You can store extra redirect_uri if you need to redirect back to for
# example CLI after receiving the callback.
#
# The original scope from auth request can also be
# stored here.
#
require_relative '../helpers/digest_helper'

class AuthorizationRequest
  include Mongoid::Document
  include Mongoid::Timestamps

  include DigestHelper

  belongs_to :user

  field :state, type: String
  field :redirect_uri, type: String
  field :scope, type: String
  field :deleted_at, type: BSON::Timestamp, default: nil
  field :expires_in, type: Integer, default: nil

  index({ state: 1 })
  index({ created_at: 1 }, { expire_after_seconds: 3600 })
  index({ deleted_at: 1 }, { sparse: true, expire_after_seconds: 1 })

  attr_accessor :state_plain

  set_callback :save, :before do |doc|
    doc.state_plain = SecureRandom.hex(32)
    doc.state = digest(doc.state_plain)
  end

  class << self
    def find_and_invalidate(state)
      ar = AuthorizationRequest.where(state: digest(state), deleted_at: nil).find_one_and_update(
        { '$set' => { deleted_at: Time.now.utc } }
      )
      if ar
        ar.destroy
        ar
      else
        nil
      end
    end
  end
end
