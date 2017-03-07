require_relative '../../spec_helper'

describe Volumes::Delete do

  let! :grid do
    grid = Grid.create!(name: 'terminal-a')
  end

  let! :volume do
    Volume.create!(
      grid: grid,
      name: 'vol',
      driver: 'some-driver',
      scope: 'node'
    )
  end

  describe '#run' do
    it 'deletes a volume that\'s not in use' do
      expect {
        outcome = described_class.new(volume: volume).run
        expect(outcome.success?).to be_truthy
      }.to change{Volume.count}. by -1
    end

    it 'does not delete a volume that\'s in use' do
      GridServices::Create.run(
          grid: grid,
          image: 'redis:2.8',
          name: 'redis',
          stateful: false,
          volumes: [
            "#{volume.name}:/data:ro"
          ]
      )
      expect {
        outcome = described_class.new(volume: volume).run
        expect(outcome.success?).to be_falsey
      }.not_to change{Volume.count}
    end

  end

end
