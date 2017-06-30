describe Duration do
  class Subject
    include Duration
  end

  let(:subject) do
    subject = Subject.new
    subject.extend(Duration)
  end

  it 'parses hours, minutes and seconds' do
    expect(subject.parse_duration('2h1m23s')).to eq(7283)
  end

  it 'parses minutes and seconds' do
    expect(subject.parse_duration('1m23s')).to eq(83)
  end

  it 'parses minutes and decimal seconds' do
    expect(subject.parse_duration('1m23.5s')).to eq(83.5)
  end

  it 'parses seconds' do
    expect(subject.parse_duration('93s')).to eq(93)
  end

  it 'fails with unknown units' do
    expect {
      subject.parse_duration('1m93x')
    }.to raise_error(ArgumentError)
  end

  it 'fails with completely unknown format' do
    expect {
      subject.parse_duration('foo')
    }.to raise_error(ArgumentError)
  end

  it 'fails with partially unknown format' do
    expect {
      puts subject.parse_duration('1m foo')
    }.to raise_error(ArgumentError)
  end

end
