require 'symmetric-encryption'
require 'symmetric_encryption/extensions/mongoid/encrypted'
require 'hkdf'

if vault_key = ENV['VAULT_KEY']
  # generate strong keys using entropy derived from the weak (human-readable) input key
  hkdf = HKDF.new(vault_key)

  # primary cipher used for encryption
  # not configured using any IV, always encrypt with a random IV
  SymmetricEncryption.cipher = SymmetricEncryption::Cipher.new(
    version:            1,
    always_add_header:  true,
    cipher_name:        'aes-256-cbc',
    key:                hkdf.next_bytes(32),
  )

  # setup legacy cipher for decoding values using the legacy truncated key + fixed IV
  if vault_iv = ENV['VAULT_IV']
    # legacy cipher used for backwards-compatibility with ciphertexts encrpyted using the truncated key
    legacy_cipher = SymmetricEncryption::Cipher.new(
      version:     0, # default, as used for encrypting existing secrets with headers
      cipher_name: 'aes-256-cbc',
      key:         vault_key[0...32],
      iv:          vault_iv[0...16],
    )

    # used to lookup cipher for vault values having a header with version=0 using the legacy key
    SymmetricEncryption.secondary_ciphers = [
      legacy_cipher,
    ]

    # used to lookup cipher for vault values not having any header
    SymmetricEncryption.select_cipher do
      legacy_cipher
    end
  end
end
