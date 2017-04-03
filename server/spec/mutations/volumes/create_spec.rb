require_relative '../../spec_helper'

describe Volumes::Create do

  let! :grid do
    grid = Grid.create!(name: 'terminal-a')
  end

  describe '#run' do
    it 'does not allow volume name to start with -' do
      expect {
        outcome = Volumes::Create.run(
          grid: grid,
          name: '-foo',
          driver: 'local',
          scope: 'instance'
        )
        expect(outcome.success?).to be_falsey
      }.to change {Volume.count}. by 0
    end

    it 'creates new grid volume' do
      expect {
        outcome = Volumes::Create.run(
          grid: grid,
          name: 'foo',
          driver: 'local',
          scope: 'instance'
        )
        expect(outcome.success?).to be_truthy
      }.to change {Volume.count}. by 1
    end

    it 'creates new grid volume with options' do
      expect {
        outcome = Volumes::Create.run(
          grid: grid,
          name: 'foo',
          driver: 'local',
          scope: 'instance',
          driver_opts: {
            foo: 'bar'
          }
        )
        expect(outcome.success?).to be_truthy
        expect(outcome.result.driver_opts['foo']).to eq('bar')
      }.to change {Volume.count}. by 1
    end

    it 'fails to create without driver' do
      outcome = Volumes::Create.run(
        grid: grid,
        name: 'foo',
        scope: 'instance'
      )
      expect(outcome.success?).to be_falsey
    end

    it 'fails to create volume with same name' do
      Volume.create!(grid: grid, name: 'foo', driver: 'local', scope: 'grid')
      expect {
        outcome = Volumes::Create.run(
          grid: grid,
          name: 'foo',
          driver: 'rexray',
          scope: 'instance'
        )
        expect(outcome.success?).to be_falsey
      }.to change {Volume.count}. by 0
    end

  end

end
