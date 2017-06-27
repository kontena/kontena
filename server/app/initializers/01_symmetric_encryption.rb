require 'symmetric-encryption'
require 'symmetric_encryption/extensions/mongoid/encrypted'

if ENV['VAULT_KEY'] && ENV['VAULT_IV']
  SymmetricEncryption.cipher = SymmetricEncryption::Cipher.new(
      key:         ENV['VAULT_KEY'][0...32],
      iv:          ENV['VAULT_IV'][0...16],
      cipher_name: 'aes-256-cbc'
  )
end
