require_relative '../../spec_helper'

describe Stacks::Create do
  let(:grid) { Grid.create!(name: 'test-grid') }

  describe '#run' do
    it 'creates a new grid stack' do
      grid
      expect {
        described_class.new(
          grid: grid,
          name: 'stack',
          stack: 'foo/bar',
          version: '0.1.0',
          registry: 'file://',
          source: '...',
          services: [{name: 'redis', image: 'redis:2.8', stateful: true }]
        ).run
      }.to change{ Stack.count }.by(1)
    end

    it 'creates stack revision' do
      outcome = described_class.new(
        grid: grid,
        name: 'stack',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        services: [{name: 'redis', image: 'redis:2.8', stateful: true }]
      ).run
      expect(outcome.result.stack_revisions.count).to eq(1)
    end

    it 'creates stack services' do
      outcome = described_class.new(
        grid: grid,
        name: 'stack',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        services: [{name: 'redis', image: 'redis:2.8', stateful: true }]
      ).run
      expect(outcome.result.grid_services.count).to eq(1)
    end

    it 'allows - char in name' do
      outcome = described_class.new(
        grid: grid,
        name: 'soome-stack',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        services: [{name: 'redis', image: 'redis:2.8', stateful: true }]
      ).run
      expect(outcome.success?).to be(true)
    end

    it 'allows numbers in name' do
      outcome = described_class.new(
        grid: grid,
        name: 'stack-12',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        services: [{name: 'redis', image: 'redis:2.8', stateful: true }]
      ).run
      expect(outcome.success?).to be(true)
    end

    it 'does not allow - as a first char in name' do
      outcome = described_class.new(
        grid: grid,
        name: '-stack',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        services: [{name: 'redis', image: 'redis:2.8', stateful: true }]
      ).run
      expect(outcome.success?).to be(false)
      expect(outcome.errors.message.keys).to include('name')
    end

    it 'does not allow special chars in name' do
      outcome = described_class.new(
        grid: grid,
        name: 'red&is',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        services: [{name: 'redis', image: 'redis:2.8', stateful: true }]
      ).run
      expect(outcome.success?).to be(false)
      expect(outcome.errors.message.keys).to include('name')
    end

    it 'does not allow empty services array' do
      outcome = described_class.new(
        grid: grid,
        name: 'redis',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        services: []
      ).run
      expect(outcome.success?).to be(false)
      expect(outcome.errors.message.keys).to include('services')
    end

    it 'creates new service linked to stack' do
      services = [{name: 'redis', image: 'redis:2.8', stateful: true }]
      outcome = described_class.new(
        grid: grid,
        name: 'soome-stack',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
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
        grid: grid,
        name: 'soome-stack',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        services: services
      ).run
      expect(outcome.success?).to be(true)
      expect(outcome.result.stack_revisions.count).to eq(1)
    end

    it 'does not create a stack if link to another stack is invalid' do
      services = [
        {
          name: 'api',
          image: 'myapi:latest',
          stateful: false,
          links: [
            {name: 'redis/redis', alias: 'redis'}
          ]
        }
      ]
      outcome = described_class.new(
        grid: grid,
        name: 'soome-stack',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        services: services
      ).run
      expect(outcome.success?).to be(false)
      expect(outcome.errors.message.keys).to include('services')
    end

    it 'does not create a stack if link within a stack is invalid' do
      services = [
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
        grid: grid,
        name: 'soome-stack',
        stack: 'foo/bar',
        version: '0.1.0',
        registry: 'file://',
        source: '...',
        services: services
      ).run
      expect(outcome.success?).to be(false)
      expect(outcome.errors.message.keys).to include('services')
    end

    it 'does not create stack if any service validation fails' do
      services = [
        {grid: grid, name: 'redis', image: 'redis:2.8', stateful: true },
        {grid: grid, name: 'invalid'}
      ]
      expect {
        outcome = described_class.new(
          grid: grid,
          name: 'soome-stack',
          stack: 'foo/bar',
          version: '0.1.0',
          registry: 'file://',
          source: '...',
          services: services
        ).run
        expect(outcome.success?).to be(false)
      }.to change{ grid.stacks.count }.by(0)
    end

    it 'does not create stack if exposed service does not exist' do
      services = [
        {grid: grid, name: 'redis', image: 'redis:2.8', stateful: true }
      ]
      expect {
        outcome = described_class.new(
          grid: grid,
          name: 'redis',
          stack: 'foo/bar',
          version: '0.1.0',
          registry: 'file://',
          source: '...',
          expose: 'foo',
          services: services
        ).run
        expect(outcome.success?).to be(false)
      }.to change{ grid.stacks.count }.by(0)
    end
  end
end
