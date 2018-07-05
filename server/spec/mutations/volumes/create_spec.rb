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

    it 'fails validation on invalid name with newlines' do
      expect {
        outcome = Volumes::Create.run(
          grid: grid,
          name: "foo\nbar",
          driver: 'local',
          scope: 'instance'
        )
        expect(outcome).to_not be_success
        expect(outcome.errors.symbolic).to eq 'name' => :matches
      }.to_not change{Volume.count}
    end

    it 'does not allow tag in driver' do
      expect {
        outcome = Volumes::Create.run(
          grid: grid,
          name: "foobar",
          driver: 'foo/bar:latest',
          scope: 'instance'
        )
        expect(outcome).to_not be_success
        expect(outcome.errors.symbolic).to eq 'driver' => :tag
      }.to_not change{Volume.count}
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
            foo: 'bar',
            'foo.bar.baz' => 'value'
          }
        )
        expect(outcome.success?).to be_truthy
        expect(outcome.result.driver_opts['foo']).to eq('bar')
        expect(outcome.result.driver_opts['foo.bar.baz']).to eq('value')
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

    it 'fails to create with invalid scope prefix' do
      outcome = Volumes::Create.run(
        grid: grid,
        name: 'foo',
        driver: 'local',
        scope: 'foo-instance'
      )
      expect(outcome).to_not be_success
      expect(outcome.errors.symbolic).to eq 'scope' => :in
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
