require_relative '../../spec_helper'

describe Volumes::Create do

  let! :grid do
    grid = Grid.create!(name: 'terminal-a')
  end

  describe '#run' do
    it 'creates new grid volume' do
      expect {
        outcome = Volumes::Create.run(
          grid: grid,
          name: 'foo',
          scope: 'node'
        )
        expect(outcome.success?).to be_truthy
      }.to change {Volume.count}. by 1
    end

    # TODO More failure cases

  end

end
