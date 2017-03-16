describe VolumesHelpers do
  class Subject
    include VolumesHelpers
  end

  let(:subject) do
    subject = Subject.new
    subject.extend(VolumesHelpers)
  end

  context 'anonymous volumes' do
    it 'parses anon vol properly' do
      volume = subject.parse_volume('/data')
      expect(volume[:path]).to eq('/data')
      expect(volume[:bind_mount]).to be_nil
      expect(volume[:volume]).to be_nil
      expect(volume[:flags]).to be_nil
    end

    it 'ignores mount flags' do
      volume = subject.parse_volume('/data:foo:bar:baz')
      expect(volume[:path]).to eq('/data')
      expect(volume[:bind_mount]).to be_nil
      expect(volume[:volume]).to be_nil
      expect(volume[:flags]).to be_nil
    end
  end

  context 'named volumes' do
    it 'parses named vol properly' do
      volume = subject.parse_volume('foo:/data')
      expect(volume[:path]).to eq('/data')
      expect(volume[:bind_mount]).to be_nil
      expect(volume[:volume]).to eq('foo')
      expect(volume[:flags]).to be_empty
    end

    it 'includes mount flags' do
      volume = subject.parse_volume('foo:/data:foo:bar:baz')
      expect(volume[:path]).to eq('/data')
      expect(volume[:bind_mount]).to be_nil
      expect(volume[:volume]).to eq('foo')
      expect(volume[:flags]).to eq('foo:bar:baz')
    end
  end

  context 'bind mounts' do
    it 'parses named vol properly' do
      volume = subject.parse_volume('/foo:/data')
      expect(volume[:path]).to eq('/data')
      expect(volume[:bind_mount]).to eq('/foo')
      expect(volume[:volume]).to be_nil
      expect(volume[:flags]).to be_empty
    end

    it 'includes mount flags' do
      volume = subject.parse_volume('/foo:/data:foo:bar:baz')
      expect(volume[:path]).to eq('/data')
      expect(volume[:bind_mount]).to eq('/foo')
      expect(volume[:volume]).to be_nil
      expect(volume[:flags]).to eq('foo:bar:baz')
    end
  end
end
