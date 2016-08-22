require_relative '../spec_helper'
require 'kontena_cli'

describe Kontena::Client do

  let(:subject) { described_class.new('https://localhost/v1/') }
  let(:http_client) { double(:http_client) }

  before(:each) do
    allow(subject).to receive(:http_client).and_return(http_client)
  end

  describe '#get' do
    it 'passes path to client' do
      allow(subject).to receive(:http_client).and_return(http_client)
      expect(http_client).to receive(:get).with(
        hash_including(path: '/v1/foo')
      ).and_return(spy(:response, status: 200))
      subject.get('foo')
    end

    it 'passes params to client' do
      allow(subject).to receive(:http_client).and_return(http_client)
      expect(http_client).to receive(:get).with(
        hash_including(query: {bar: 'baz'})
      ).and_return(spy(:response, status: 200))
      subject.get('foo', {bar: 'baz'})
    end

    it 'passes params to client' do
      allow(subject).to receive(:http_client).and_return(http_client)
      expect(http_client).to receive(:get).with(
        hash_including(headers: hash_including(:'Some-Header' => 'value'))
      ).and_return(spy(:response, status: 200))
      subject.get('foo', nil, {:'Some-Header' => 'value'})
    end
  end

  describe '#get_stream' do
    let(:response_block) { Proc.new{ } }

    it 'passes path & response_block to client' do
      expect(http_client).to receive(:get).with(
        hash_including(path: '/v1/foo', response_block: response_block)
      ).and_return(spy(:response, status: 200))
      subject.get_stream('foo', response_block)
    end

    it 'passes params to client' do
      expect(http_client).to receive(:get).with(
        hash_including(query: {bar: 'baz'})
      ).and_return(spy(:response, status: 200))
      subject.get_stream('foo', response_block, {bar: 'baz'})
    end

    it 'passes params to client' do
      expect(http_client).to receive(:get).with(
        hash_including(headers: hash_including(:'Some-Header' => 'value'))
      ).and_return(spy(:response, status: 200))
      subject.get_stream('foo', response_block, nil, {:'Some-Header' => 'value'})
    end
  end

  describe '#post' do
    let(:data) do
      { foo: 'bar' }
    end

    it 'passes path and object to client' do
      expect(http_client).to receive(:post).with(
        hash_including(path: '/v1/foo', body: kind_of(String))
      ).and_return(spy(:response, status: 200))
      subject.post('foo', data)
    end

    it 'passes params to client' do
      expect(http_client).to receive(:post).with(
        hash_including(query: {bar: 'baz'})
      ).and_return(spy(:response, status: 200))
      subject.post('foo', data, {bar: 'baz'})
    end

    it 'passes params to client' do
      expect(http_client).to receive(:post).with(
        hash_including(headers: hash_including(:'Some-Header' => 'value'))
      ).and_return(spy(:response, status: 200))
      subject.post('foo', data, nil, {:'Some-Header' => 'value'})
    end
  end

  describe '#put' do
    let(:data) do
      { foo: 'bar' }
    end

    it 'passes path and object to client' do
      expect(http_client).to receive(:put).with(
        hash_including(path: '/v1/foo', body: kind_of(String))
      ).and_return(spy(:response, status: 200))
      subject.put('foo', data)
    end

    it 'passes params to client' do
      expect(http_client).to receive(:put).with(
        hash_including(query: {bar: 'baz'})
      ).and_return(spy(:response, status: 200))
      subject.put('foo', data, {bar: 'baz'})
    end

    it 'passes params to client' do
      expect(http_client).to receive(:put).with(
        hash_including(headers: hash_including(:'Some-Header' => 'value'))
      ).and_return(spy(:response, status: 200))
      subject.put('foo', data, nil, {:'Some-Header' => 'value'})
    end
  end

  describe '#delete' do
    let(:data) do
      { foo: 'bar' }
    end

    it 'passes path to client' do
      expect(http_client).to receive(:delete).with(
        hash_including(path: '/v1/foo')
      ).and_return(spy(:response, status: 200))
      subject.delete('foo')
    end

    it 'passes params to client' do
      expect(http_client).to receive(:delete).with(
        hash_including(query: {bar: 'baz'})
      ).and_return(spy(:response, status: 200))
      subject.delete('foo', nil, {bar: 'baz'})
    end

    it 'passes params to client' do
      expect(http_client).to receive(:delete).with(
        hash_including(headers: hash_including(:'Some-Header' => 'value'))
      ).and_return(spy(:response, status: 200))
      subject.delete('foo', nil, nil, {:'Some-Header' => 'value'})
    end
  end
end
