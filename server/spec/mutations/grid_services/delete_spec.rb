require_relative '../../spec_helper'

describe GridServices::Delete do
  let(:user) { User.create!(email: 'joe@domain.com')}
  let(:grid) {
    grid = Grid.create!(name: 'test-grid')
    grid.users << user
    grid
  }
  let(:redis_service) { GridService.create(grid: grid, name: 'redis', image_name: 'redis:2.8')}
  let(:web_service) do
    link = GridServiceLink.new(
        linked_grid_service: redis_service,
        alias: 'redis'
    )
    GridService.create(grid: grid, name: 'web', image_name: 'web:latest', grid_service_links: [link])
  end

  describe '#run' do
    it 'deletes a service' do
      service = redis_service
      expect {
        described_class.new(current_user: user, grid_service: service).run
      }.to change{ GridService.count }.by(-1)
    end

    context 'when service is linked to another service' do
      it 'returns error' do
        web_service

        service = redis_service
        expect {
          outcome = described_class.new(current_user: user, grid_service: service).run
          expect(outcome.success?).to be_falsey
          expect(outcome.errors.message["service"]).to eq("Cannot delete service that is linked to another service (web)")
        }.to change{ GridService.count }.by(0)
      end
    end
  end
end
