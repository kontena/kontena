class ReencryptVaultSecrets < Mongodb::Migration
  include Logging

  def self.up
    GridSecret.each do |secret|
      info "Re-encrypting secret #{secret.to_path}..."
      secret.value = secret.value
      secret.save
    end
  end
end
