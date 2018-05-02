require_relative '../../../db/migrations/32_clean_up_orphan_certificates'

describe CleanUpOrphanCertificates do
  let!(:grid) { Grid.create!(name: 'test-grid') }
  let!(:certificate) { Certificate.create!(grid: grid, subject: 'test.example.com',
    valid_until: Time.now + 3600,
  ) }

  context 'for an existing grid' do
    it 'does nothing' do
      expect{
        described_class.up
      }.to_not change{Certificate.find_by(subject: 'test.example.com')}.from(certificate)
    end
  end

  context 'for an missing grid' do
    before do
      grid.collection.delete_one({_id: grid.id})
    end

    it 'removes the orphaned certificate' do
      expect{
        described_class.up
      }.to change{Certificate.find_by(subject: 'test.example.com')}.from(certificate).to(nil)
    end
  end
end
