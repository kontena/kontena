describe IPAddr do
  describe '#prefixlen' do
    it 'has a prefix length' do
      expect(IPAddr.new('0.0.0.0/0').prefixlen).to eq 0
      expect(IPAddr.new('10.80.0.0/12').prefixlen).to eq 12
      expect(IPAddr.new('10.80.0.0/24').prefixlen).to eq 24
      expect(IPAddr.new('10.80.0.1/24').prefixlen).to eq 24
      expect(IPAddr.new('10.80.1.1/32').prefixlen).to eq 32
    end
  end

  describe 'last' do
    it 'returns the correct IPAddr' do
      expect(IPAddr.new('10.81.0.0/16').last.to_s).to eq '10.81.255.255'
    end
  end

  describe '#[]' do
    context "for 10.81.0.0/16" do
      subject do
        IPAddr.new('10.81.0.0/16')
      end

      it 'returns the correct IP' do
        expect(subject[0].to_s).to eq '10.81.0.0'
        expect(subject[1].to_s).to eq '10.81.0.1'
        expect(subject[2].to_s).to eq '10.81.0.2'
        expect(subject[255].to_s).to eq '10.81.0.255'
        expect(subject[256].to_s).to eq '10.81.1.0'
        expect(subject[257].to_s).to eq '10.81.1.1'
        expect(subject[256 * 256 - 1].to_s).to eq '10.81.255.255'
      end

      it 'raises on invalid offset' do
        expect{subject[256 * 256]}.to raise_error(ArgumentError)
        expect{subject[256 * 256 + 1]}.to raise_error(ArgumentError)
      end
    end
  end

  describe '#split' do
    context "for 10.81.0.0/16" do
      subject do
        IPAddr.new('10.81.0.0/16')
      end

      it "splits in twain" do
        expect(subject.split.map{|i| i.to_cidr}).to eq ['10.81.0.0/17', '10.81.128.0/17']
      end
    end
  end
end
