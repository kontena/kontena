require_relative '../../spec_helper'

describe EventStream::GridEventServer do

  let(:grid) { Grid.create! }

  describe '.serve' do
    after(:each) {EventStream::GridEventServer::LISTENERS.clear }

    context 'on open' do
      it 'creates event listener' do
        ws = spy
        event = double
        listener = spy
        expect(ws).to receive(:on).once.with(:open).and_yield(event)
        expect(EventStream::GridEventListener).to receive(:new).with(grid).and_return(listener)

        EventStream::GridEventServer.serve(ws, grid, {})
      end

      it 'adds new client to listener' do
        ws = spy
        event = double
        listener = spy
        expect(ws).to receive(:on).with(:open).and_yield(event)
        allow(EventStream::GridEventListener).to receive(:new).with(grid).and_return(listener)
        expect(listener).to receive(:add_client).with(ws, ['*'])
        EventStream::GridEventServer.serve(ws, grid, {})
      end

    end

    context 'on close' do
      it 'remove client from listener' do
        ws = spy
        event = double
        listener = spy
        expect(ws).to receive(:on).once.with(:close).and_yield(event)
        expect(EventStream::GridEventServer).to receive(:find_listener).with(grid).and_return(listener)
        expect(listener).to receive(:remove_client).with(ws)
        EventStream::GridEventServer.serve(ws, grid, {})
      end
    end
  end

end