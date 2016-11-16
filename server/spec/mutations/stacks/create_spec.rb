require_relative '../../spec_helper'

describe Stacks::Create do
  let(:user) { User.create!(email: 'joe@domain.com')}

  let(:grid) {
    grid = Grid.create!(name: 'test-grid')
    grid.users << user
    grid
  }

  describe '#run' do
    it 'creates a new grid stack' do
      grid
      expect {
        described_class.new(
          current_user: user,
          grid: grid,
          name: 'stack',
          services: []
        ).run
      }.to change{ Stack.count }.by(1)
    end

    it 'allows - char in name' do
      outcome = described_class.new(
        current_user: user,
        grid: grid,
        name: 'soome-stack',
        services: []
      ).run
      expect(outcome.success?).to be(true)
    end

    it 'allows numbers in name' do
      outcome = described_class.new(
        current_user: user,
        grid: grid,
        name: 'stack-12',
        services: []
      ).run
      expect(outcome.success?).to be(true)
    end

    it 'does not allow - as a first char in name' do
      outcome = described_class.new(
        current_user: user,
        grid: grid,
        name: '-stack',
        services: []
      ).run
      expect(outcome.success?).to be(false)
      expect(outcome.errors.message.keys).to include('name')
    end

    it 'does not allow special chars in name' do
      outcome = described_class.new(
        current_user: user,
        grid: grid,
        name: 'red&is',
        services: []
      ).run
      expect(outcome.success?).to be(false)
      expect(outcome.errors.message.keys).to include('name')
    end

    it 'creates new service linked to stack' do
      services = [{name: 'redis', image: 'redis:2.8', stateful: true }]
      outcome = described_class.new(
        current_user: user,
        grid: grid,
        name: 'soome-stack',
        services: services
      ).run

      expect(outcome.success?).to be(true)
      expect(outcome.result.stack_revisions.count).to eq(1)
    end

    it 'creates stack with linked services' do
      services = [
        {
          name: 'redis',
          image: 'redis:2.8',
          stateful: true
        },
        {
          name: 'api',
          image: 'myapi:latest',
          stateful: false,
          links: [
            {name: 'redis', alias: 'redis'}
          ]
        }
      ]
      outcome = described_class.new(
        current_user: user,
        grid: grid,
        name: 'soome-stack',
        services: services
      ).run
      expect(outcome.success?).to be(true)
      expect(outcome.result.stack_revisions.count).to eq(1)
    end

    it 'does not create stack if any service validation fails' do
      services = [
        {grid: grid, name: 'redis', image: 'redis:2.8', stateful: true },
        {grid: grid, name: 'invalid'}
      ]
      expect {
        outcome = described_class.new(
          current_user: user,
          grid: grid,
          name: 'soome-stack',
          services: services
        ).run
        expect(outcome.success?).to be(false)
      }.to change{ grid.stacks.count }.by(0)
    end

    # it 'does not allow duplicate name within a grid' do
    #   GridService.create!(name: 'redis', image_name: 'redis:latest', grid: grid)
    #   outcome = described_class.new(
    #     current_user: user,
    #     grid: grid,
    #     image: 'redis:2.8',
    #     name: 'redis',
    #     stateful: true
    #   ).run
    #   expect(outcome.success?).to be(false)
    #   expect(outcome.errors.message.keys).to include('name')
    # end


  end
end
