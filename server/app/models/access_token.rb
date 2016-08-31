require 'uri'
require_relative '../helpers/config_helper'

class AccessToken
  include Mongoid::Document
  include Mongoid::Timestamps

  include ConfigHelper

  belongs_to :user
  validates_presence_of :scopes, :user

  validates :refresh_token, uniqueness: { scope: :internal, allow_nil: true }

  field :token_type, type: String, default: 'bearer'
  field :token, type: String
  field :refresh_token, type: String
  field :expires_at, type: Time
  field :scopes, type: Array
  field :deleted_at, type: Time, default: nil
  field :internal, type: Boolean, default: true
  field :code, type: String, default: nil

  index({ user_id: 1 })
  index({ internal: 1 })
  index({ token: 1 }, { unique: true })
  index({ refresh_token: 1 }, { sparse: true })
  index({ expires_at: 1 }, { sparse: true })
  index({ deleted_at: 1 }, { sparse: true })
  index({ code: 1 }, { sparse: true, unique: true })

  attr_accessor :token_plain
  attr_accessor :refresh_token_plain

  # Fake setter. When true (or a predefined code is supplied) the
  # token will get a code upon creation.
  #
  # Without this, you would have to do something like
  #   AccessToken.new(code: 'abcd')
  # Now you can do
  #   AccessToken.new(with_code: true)
  def with_code=(boolean_or_code)
    case boolean_or_code
    when TrueClass then generate_code
    when String then self[:code] = boolean_or_code
    else nil
    end
  end

  # Encrypt the plaintext tokens before saving
  set_callback :save, :before do |doc|
    doc.expires_at = nil unless doc.expires_at.to_i > 0
    if doc.internal?
      doc.token_plain ||= SecureRandom.hex(16) unless doc.token
      unless doc.refresh_token || doc.expires_at.nil?
        doc.refresh_token_plain ||= SecureRandom.hex(32)
      end
      doc.token ||= self.encrypt(doc.token_plain)
      doc.refresh_token ||= self.encrypt(doc.refresh_token_plain) if doc.refresh_token_plain
    end
  end

  class << self
    # Finds an access_token by refresh_token and updates it in place to
    # mark it as used. Otherwise two threads could issue an access token
    # using the same refresh_token at the same time.
    #
    # Returns the marked access token or nil
    #
    # TODO find_and_modify is deprecated in mongoid 5
    #
    # @param [String] refresh_token
    # @return [AccessToken] access_token
    def find_internal_by_refresh_token(refresh_token)
      old_token = AccessToken.where(
        refresh_token: self.encrypt(refresh_token),
        deleted_at: nil,
        internal: true
      ).find_and_modify({ '$set' => { deleted_at: Time.now.utc } })

      return nil unless old_token
      return nil if old_token.expired?

      new_token = AccessToken.create!(
        token_type: 'bearer',
        expires_at: Time.now.utc + 7200,
        scopes: old_token.scopes,
        internal: true,
        user: old_token.user
      )

      old_token.destroy
      new_token
    end

    def find_internal_by_access_token(access_token)
      AccessToken.where(
        token: self.encrypt(access_token),
        deleted_at: nil,
        internal: true
      ).find_and_modify({ '$set' => { updated_at: Time.now.utc } })
    end
   
    # Since we don't know the original saved tokens, we just delete the old one and generate a duplicate with the same scope + user
    #
    # TODO consider hashing codes.
    def find_internal_by_code(code)
      coded_token = AccessToken.where(code: code, deleted_at: nil).find_and_modify({ '$set' => { deleted_at: Time.now.utc } })

      return nil unless coded_token

      new_token = AccessToken.create!(
        token_type: 'bearer',
        expires_at: coded_token.expires_at,
        scopes: coded_token.scopes,
        internal: true,
        user: coded_token.user
      )

      coded_token.destroy
      new_token
    end
  end

  def expires?
    !expires_at.nil? && expires_at.to_i > 0
  end

  def used?
    !deleted_at.nil?
  end

  def expired?
    (expires? && expires_at && expires_at < Time.now.utc) || used?
  end

  def generate_code(code_bytes = 6)
    self[:token_type] = 'authorization_code'
    self[:code] = SecureRandom.hex(code_bytes)
  end

  def has_code?
    !self[:code].nil?
  end

  # Converts the access token to uri encoded format usable in 
  # redirects and as a x-www-form-encoded body response.
  #
  # If uri is not defined, just the parameters will be returned,
  # otherwise a new uri will be built including everything from the
  # defined uri plus the token as parameters.
  #
  # If uri is defined and as_fragment is true then the query parameters
  # will be included as url's anchor part aka fragment. This is used
  # in implicit grant flow to avoid sending the tokens to the callback
  # server, only to the javascript application "receiving" the callback.
  def to_query(state: nil, uri: nil, as_fragment: false)
    query = []
    query << ["state", state] unless state.nil?

    if self.code
      query << ["code", self.code]
    else
      query << ["access_token",  self.token_plain]         if self.token_plain
      query << ["refresh_token", self.refresh_token_plain] if self.refresh_token_plain
      query << ["expires_in",    self.expires_in]          if self.expires_at
      query << ["username",      self.user.name]
    end

    query << ["server_name",   Server.name] if Server.name

    if uri
      new_uri = URI.parse(uri)
      if as_fragment
        new_uri.fragment = URI.encode_www_form(query)
      else
        query += URI.decode_www_form(new_uri.query) if new_uri.query
        new_uri.query = URI.encode_www_form(query)
      end
      new_uri.to_s
    else
      URI.encode_www_form(query)
    end
  end

  def expires_in
    return nil if expires_at.nil?
    expires_at.to_i - Time.now.utc.to_i
  end

  # Returns true if user has all requested scopes
  def has_scope?(*scopes)
    return true if scopes.empty?
    Array(scopes.flatten).none?{ |scope| !self.scopes.include?(scope) }
  end

  # Returns true if user has any requested scopes
  def has_any_scope?(*scopes)
    return true if scopes.empty?
    Array(scopes.flatten).any?{ |scope| self.scopes.include?(scope) }
  end
end
