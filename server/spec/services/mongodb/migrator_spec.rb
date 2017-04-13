
describe Mongodb::Migrator do

  describe '#migrations' do
    before(:each) do
      expect(subject).to receive(:load_migration_files).and_return(
        [
          './db/migrations/02_foo.rb',
          './db/migrations/01_bar.rb',
          './db/migrations/03_baz.rb',
        ]
      )
    end

    it 'returns migrations in correct order' do
      migrations = subject.migrations
      expect(migrations[0].version).to eq(1)
      expect(migrations[2].version).to eq(3)
    end
  end

  describe '#release_stale_lock' do
    it 'does nothing if lock is not stale' do
      DistributedLock.create(name: described_class::LOCK_NAME, created_at: Time.now.utc)
      expect {
        subject.release_stale_lock
      }.not_to change { DistributedLock.count }
    end

    it 'removes lock if stale' do
      DistributedLock.create(name: described_class::LOCK_NAME, created_at: 4.minutes.ago)
      expect {
        subject.release_stale_lock
      }.to change { DistributedLock.count }.by(-1)
    end
  end
end
