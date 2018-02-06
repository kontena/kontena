class ReencryptVaultSecrets < Mongodb::Migration
  include Logging

  def self.up
    GridSecret.each do |secret|
      info "Re-encrypting GridSecret #{secret.to_path}..."
      secret.value = secret.value
      secret.save
    end

    Certificate.each do |cert|
      info "Re-encrypting Certificate #{cert.to_path}..."
      cert.private_key = cert.private_key
      cert.save
    end

    GridDomainAuthorization.each do |authz|
      if authz.encrypted_tls_sni_certificate
        info "Re-encrypting GridDomainAuthorization #{authz.to_path}..."
        authz.tls_sni_certificate = authz.tls_sni_certificate
        authz.save
      end
    end

    Configuration.each do |config|
      if Configuration.should_encrypt?(config.key)
        info "Re-encrypting Configuration #{config.key}..."
        Configuration[config.key] = Configuration[config.key]
      end
    end
  end
end
