
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
end
