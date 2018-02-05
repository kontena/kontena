require 'spec_helper'

describe 'external-registry ls' do
  context 'when empty' do
    it "outputs headers" do
      k = run!('kontena external-registry ls')
      expect(k.out).to match(/NAME/)
      expect(k.out.lines.size).to eq 1
    end

    context '-q' do
      it "outputs nothing" do
        k = run! 'kontena external-registry ls -q'
        expect(k.out.strip).to be_empty
      end
    end
  end

  context 'when not empty' do
    before do
      run! 'kontena external-registry add -u foo -e foo@no.email -p secret registry.domain.com'
    end

    after do
      run 'kontena external-registry rm --force registry.domain.com'
    end

    it "returns a list" do
      k = run!('kontena external-registry ls')
      expect(k.out.lines.first).to match(/NAME/)
      expect(k.out.lines.last).to start_with 'registry.domain.com'
      expect(k.out.lines.last).to include 'foo'
      expect(k.out.lines.last).not_to include 'secret'
      expect(k.out.lines.size).to eq 2
    end

    context '-q' do
      it "outputs the registry name" do
        k = run! 'kontena external-registry ls -q'
        expect(k.out.strip).to eq 'registry.domain.com'
      end
    end
  end
end
