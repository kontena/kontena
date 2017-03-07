
describe AuditLogs::Create do

  let(:user) { User.create!(email: 'joe@domain.com')}
  let(:grid) { Grid.create!(name: 'test-grid')}
  let(:service) { GridService.create!(grid: grid, name: 'redis', image_name: 'redis:2.8')}

  describe '#run' do
    it 'creates an audit log item' do
      expect {
        described_class.new(
          user: user,
          grid: grid,
          event_name: 'service',
          event_status: 'created',
          resource_type: service.class.name,
          resource_id: service.id.to_s,
          source_ip: '127.0.0.1'
        ).run
      }.to change{ AuditLog.count }.by(1)
    end

    it 'returns error if event info is missing' do
      expect {
        outcome = described_class.new(
            user: user,
            grid: grid,
            resource_type: service.class.name,
            resource_id: service.id.to_s,
            source_ip: '127.0.0.1'
        ).run
        expect(outcome.success?).to be_falsey
      }.to change{ AuditLog.count }.by(0)
    end

    it 'returns error if resource info is missing' do
      expect {
        outcome = described_class.new(
            user: user,
            grid: grid,
            event_name: 'service',
            event_status: 'created',
            source_ip: '127.0.0.1'
        ).run
        expect(outcome.success?).to be_falsey
      }.to change{ AuditLog.count }.by(0)
    end
  end
end
