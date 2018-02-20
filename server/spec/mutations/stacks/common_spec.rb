
describe Stacks::Common do
  let(:described_class) {
    Class.new do
      include Stacks::Common
    end
  }

  describe '#sort_services' do
    let(:services) do
      [
        {
          name: 'api',
          links: [
            {name: 'redis', alias: 'redis'},
            {name: 'postgres', alias: 'postgres'},
            {name: 'lb', alias: 'lb'}
          ]
        },
        {
          name: 'sidekiq',
          links: [
            {name: 'redis', alias: 'redis'},
            {name: 'postgres', alias: 'postgres'}
          ]
        },
        {
          name: 'redis',
          links: [
            {name: 'lb', alias: 'lb'}
          ]
        },
        {
          name: 'postgres',
          links: []
        },
        {
          name: 'lb',
          links: []
        },
      ]
    end

    it 'sorts services by links' do
      sorted = subject.sort_services(services)
      expect(sorted[0][:name]).to eq('postgres')
      expect(sorted[1][:name]).to eq('lb')
      expect(sorted[2][:name]).to eq('redis')
      expect(sorted[3][:name]).to eq('sidekiq')
    end
  end
end
