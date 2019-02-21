class Certificate
  include Mongoid::Document
  include Mongoid::Timestamps

  field :subject, type: String
  field :valid_until, type: DateTime
  field :alt_names, type: Array
  field :encrypted_private_key, type: String, encrypted: { random_iv: true } # PEM encoded
  field :certificate, type: String # PEM encoded certificate, no need to encrypt
  field :chain, type: String # Trust chain

  belongs_to :grid

  validates_presence_of :subject, :valid_until
  validates_uniqueness_of :subject, scope: [:grid_id]
  validates_format_of :private_key, with: /\n\z/
  validates_format_of :certificate, with: /\n\z/
  validates_format_of :chain, with: /\n\z/, allow_blank: true

  index({ grid_id: 1 })
  index({ subject: 1 })
  index({ grid_id: 1, subject: 1 }, {unique: true})

  def to_path
    "#{self.grid.try(:name)}/#{self.subject}"
  end

  # @return [String] Actual certificate and the trust chain bundled together
  def full_chain
    self.certificate + self.chain
  end

  # @return [String] Fullchain and private key bundle, mainly for HAProxy
  def bundle
    self.full_chain + self.private_key
  end

  # @return [Array<String>]
  def all_domains
    [self.subject] + self.alt_names.to_a
  end

  # Checks if all domains are authorized with tls-sni, we can't automate anything else for now
  # @return [Boolean]
  def auto_renewable?
    self.all_domains.each do |domain|
      domain_auth = self.grid.grid_domain_authorizations.find_by(domain: domain)
      unless domain_auth && domain_auth.auto_renewable?
        return false
      end
    end

    true
  end

end
