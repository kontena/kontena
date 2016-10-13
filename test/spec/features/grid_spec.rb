require 'spec_helper'

describe 'grid commands' do
  context 'create' do
    it 'creates a new grid' do
      run("kontena grid rm --force foo")
      k = run("kontena grid create foo")
      expect(k.code).to eq(0)
      k = run("kontena grid ls")
      expect(k.out).to include("foo *")
      run("kontena grid rm --force foo")
    end
  end

  context 'update' do
    before(:each) do
      run("kontena grid create test-1")
    end

    after(:each) do
      run("kontena grid rm --force test-1")
    end

    it 'updates grid' do
      k = run("kontena grid update --statsd-server 127.0.0.1:1234 test-1")
      expect(k.code).to eq(0)
      k = run("kontena grid show test-1")
      expect(k.out).to match(/statsd: 127.0.0.1:1234/)
    end

    it 'returns error if grid does not exist' do
      k = run("kontena grid update --statsd-server 127.0.0.1:1234 aaaaa")
      expect(k.code).not_to eq(0)
    end
  end

  context 'cloud-config' do
    before(:each) do
      run("kontena grid create test-1")
    end

    after(:each) do
      run("kontena grid rm --force test-1")
    end

    it 'shows cloud-config template' do
      k = run("kontena grid cloud-config e2e")
      expect(k.out.split("\r\n")[0]).to eq('#cloud-config')
    end
  end
end
