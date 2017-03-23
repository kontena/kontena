
describe Configuration do

  describe '#get' do
    it 'should get values' do
      Configuration['test00'] = 1
      expect(Configuration['test00']).to eq 1
      expect(Configuration.get('test00')).to eq 1
    end

    it 'should decrypt values' do
      Configuration['test00_secret'] = "foo"
      expect(Configuration.where(key: 'test00_secret').first.value["v"]).not_to eq('foo')
      expect(Configuration['test00_secret']).to eq "foo"
    end
  end

  describe '#delete' do
    it 'should remove the key' do
      Configuration['test01'] = 1
      Configuration.delete('test01')
      expect(Configuration['test01']).to be_nil
      expect(Configuration.where(key: 'test01').count).to eq 0
    end
  end

  describe '#increment' do
    it 'should increment values' do
      Configuration['test01'] = 0
      Configuration.increment('test01')
      expect(Configuration['test01']).to eq 1
    end

    it 'should increment nil values to 1' do
      Configuration.increment('test02')
      expect(Configuration['test02']).to eq 1
    end
  end

  describe '#decrement' do
    it 'should decrement values' do
      Configuration['test01'] = 1
      Configuration.decrement('test01')
      expect(Configuration['test01']).to eq 0
    end

    it 'should decrement nil values to -1' do
      Configuration.decrement('test03')
      expect(Configuration['test03']).to eq -1
    end
  end

  describe '#put' do
    it 'should not create duplicate entries' do
      threads = []
      10.times do 
        threads << Thread.new do
          10.times do
            Configuration.put("test123", "abcd1234")
          end
        end
      end
      threads.map(&:join)
      expect(Configuration.where(key: 'test123').count).to eq 1
      expect(Configuration.get('test123')).to eq 'abcd1234'
    end

    it 'should encrypt secret keys' do
      Configuration['foo_secret'] = "hello"
      expect(Configuration.where(key: 'foo_secret').first.value["v"]).not_to eq('hello')
      expect(Configuration.get('foo_secret')).to eq 'hello'
      expect(Configuration.should_encrypt?('foo')).to be_falsey
      expect(Configuration.should_encrypt?('foo_secret')).to be_truthy
      expect(Configuration.should_encrypt?('server.salt')).to be_truthy
    end

    it 'should allow setting values via ||=' do
      expect(Configuration['test999']).to be_nil
      Configuration['test999'] ||= 'foo'
      expect(Configuration['test999']).to eq 'foo'
      Configuration['test999'] ||= 'bar'
      expect(Configuration['test999']).to eq 'foo'
    end

    it 'should not create multiple entries when using ||=' do
      threads = []
      i = 0
      Configuration[:test3456] ||= "foo1"
      10.times do 
        threads << Thread.new do
          i += 1
          10.times do
            Configuration[:test3456] ||= "foo#{i}"
          end
        end
      end
      threads.map(&:join)
      expect(Configuration.where(key: 'test3456').count).to eq 1
      expect(Configuration.get('test3456')).to eq 'foo1'
    end
  end
end
