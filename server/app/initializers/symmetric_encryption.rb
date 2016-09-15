require 'symmetric-encryption'
require 'symmetric_encryption/extensions/mongoid/encrypted'

if ENV['VAULT_KEY'] && ENV['VAULT_IV']
  SymmetricEncryption.cipher = SymmetricEncryption::Cipher.new(
      key:         ENV['VAULT_KEY'],
      iv:          ENV['VAULT_IV'],
      cipher_name: 'aes-256-cbc'
  )
end
