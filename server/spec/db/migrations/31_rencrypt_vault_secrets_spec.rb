require_relative '../../../db/migrations/31_reencrypt_vault_secrets'

describe ReencryptVaultSecrets do
  let!(:grid) { Grid.create!(name: 'test-grid') }

  let(:legacy_cipher) { SymmetricEncryption.cipher(0) }
  let(:primary_cipher) { SymmetricEncryption.cipher }

  let(:legacy_key) { legacy_cipher.send :key }
  let(:primary_key) { primary_cipher.send :key }

  describe 'SymmetricEncryption legacy cipher' do
    it 'has an IV configured' do
      expect(legacy_cipher.iv).to be_a String
    end

    it 'uses the raw VAULT_KEY' do
      expect(legacy_key).to eq ENV['VAULT_KEY'][0...32]
    end

    context 'for an old encrpyted value' do
      let(:encrypted_value) { legacy_cipher.encrypt('foobar', false) }
      let(:decoded_value) { SymmetricEncryption.cipher.decode(encrypted_value) }

      it 'does not have a header' do
        expect(SymmetricEncryption::Cipher.has_header?(decoded_value)).to be false
      end

      it 'decrypts correctly' do
        expect(SymmetricEncryption.decrypt(encrypted_value)).to eq 'foobar'
      end
    end
  end

  describe 'SymmetricEncryption primary cipher' do
    it 'does not have any IV configured' do
      expect(primary_cipher.iv).to be_nil
    end

    it 'has a different key than the legacy cipher' do
      expect(primary_key).to_not eq legacy_key
    end

    context 'for a newly encrypted value with a random IV' do
      let(:encrypted_value) { SymmetricEncryption.encrypt('foobar', true) }
      let(:decoded_value) { SymmetricEncryption.cipher.decode(encrypted_value) }
      let(:cipher_header) { SymmetricEncryption::Cipher.parse_header!(decoded_value) }

      it 'encrypts with a header' do
        expect(SymmetricEncryption::Cipher.has_header?(decoded_value)).to be true
      end

      it 'encrypts with the correct version' do
        expect(cipher_header.version).to eq primary_cipher.version
      end

      it 'encrpyts with a random IV' do
        expect(cipher_header.iv).to_not be_nil
      end

      it 'decrypts correctly' do
        expect(SymmetricEncryption.decrypt(encrypted_value)).to eq 'foobar'
      end
    end
  end

  context 'with legacy secrets' do
    let!(:grid_secret) { GridSecret.create!(grid: grid, name: 'test', encrypted_value: legacy_cipher.encrypt('foobar', false)) }
    let(:encrypted_value) { grid_secret.reload.encrypted_value }
    let(:decoded_value) { SymmetricEncryption.cipher.decode(encrypted_value) }

    context 'before migration' do

      it 'does not have a header' do
        expect(SymmetricEncryption::Cipher.has_header?(decoded_value)).to be false
      end

      it 'decrypts with the legacy cipher' do
        expect(legacy_cipher.decrypt(encrypted_value)).to eq 'foobar'
      end

      it 'is decryptable via the model' do
        expect(grid_secret.value).to eq 'foobar'
      end
    end

    context 'after migration' do
      before do
        described_class.up
      end

      let(:cipher_header) { SymmetricEncryption::Cipher.parse_header!(decoded_value) }

      it 'has a header' do
        expect(SymmetricEncryption::Cipher.has_header?(decoded_value)).to be true
      end

      it 'encrypts with the correct version' do
        expect(cipher_header.version).to eq primary_cipher.version
      end

      it 'encrpyts with a random IV' do
        expect(cipher_header.iv).to_not be_nil
      end

      it 'decrypts with the primary cipher' do
        expect(primary_cipher.decrypt(encrypted_value)).to eq 'foobar'
      end

      it 'is decryptable via the model' do
        expect(grid_secret.value).to eq 'foobar'
      end
    end
  end
end
