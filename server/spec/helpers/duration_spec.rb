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

  it 'parses unknown units to zero' do
    expect(subject.parse_duration('1m93x')).to eq(60)
  end

  it 'parses unknown format to zero' do
    expect(subject.parse_duration('foo')).to eq(0)
  end

end
