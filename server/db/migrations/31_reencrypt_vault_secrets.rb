class ReencryptVaultSecrets < Mongodb::Migration
  include Logging

  def self.up
    GridSecret.each do |secret|
      info "Re-encrypting GridSecret #{secret.to_path}..."
      secret.value = secret.value
      secret.save
    end

    Certificate.all.reject { |c| c.grid.nil? }.each do |cert|
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

  def self.down
    legacy_cipher = SymmetricEncryption.cipher(0)

    Configuration.each do |config|
      if Configuration.should_encrypt?(config.key)
        info "Rollback Configuration #{config.key}..."
        Configuration.find_by(key: config.key).set(value: {v: legacy_cipher.encrypt(Configuration[config.key]) })
      end
    end

    GridDomainAuthorization.each do |authz|
      if authz.encrypted_tls_sni_certificate
        info "Rollback GridDomainAuthorization #{authz.to_path}..."
        authz.set(encrypted_tls_sni_certificate: legacy_cipher.encrypt(authz.tls_sni_certificate))
      end
    end

    Certificate.all.reject { |c| c.grid.nil? }.each do |cert|
      info "Rollback Certificate #{cert.to_path}..."
      cert.set(encrypted_private_key: legacy_cipher.encrypt(cert.private_key))
    end

    GridSecret.each do |secret|
      info "Rollback GridSecret #{secret.to_path}..."
      secret.set(encrypted_value: legacy_cipher.encrypt(secret.value))
    end
  end
end
