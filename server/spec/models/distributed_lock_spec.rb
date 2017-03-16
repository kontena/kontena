require_relative '../spec_helper'

describe DistributedLock do
  it { should have_fields(:name, :lock_id, :created_at)}
  it { should have_index_for(name: 1).with_options(unique: true) }

  before(:each) do

  end

  describe '.with_lock' do
    it 'locks access between threads' do
      3.times do
        threads = []
        results = []
        described_class.with_lock('foobar'){ sleep 0.1; results << 'first_lock'}
        3.times {
          threads << Thread.new{ described_class.with_lock('foobar'){ results << 'lock'} }
        }
        threads.each(&:join)
        expect(results[0]).to eq('first_lock')
      end
    end

    it 'returns false if getting lock timeouts' do
      threads = []
      threads << Thread.new {
        expect(described_class.with_lock('foo1') { sleep 0.1; "thread A got lock" }).to eq("thread A got lock")
      }
      threads << Thread.new {
        sleep 0.01
        expect(described_class.with_lock('foo1', 0.01) { "thread B got lock" }).to eq(false)
      }
      threads.each(&:join)
    end
  end

  describe '.obtain_lock' do
    it 'creates lock' do
      expect(described_class.obtain_lock('foo1')).to be_truthy
      expect(described_class.obtain_lock('foo1')).to eq(false)
    end
  end

  describe '.release_lock' do
    it 'releases lock' do
      lock = described_class.obtain_lock('foo1')
      expect(described_class.obtain_lock('foo1')).to eq(false)
      described_class.release_lock('foo1', lock)
      expect(described_class.obtain_lock('foo1')).to be_truthy
    end
  end
end
