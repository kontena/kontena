
describe GridSecret do
  it { should be_timestamped_document }
  it { should have_fields(:name, :encrypted_value).of_type(String) }
  it { should belong_to(:grid) }
  let(:grid) do
    Grid.create!(name: 'terminal-a')
  end

  let(:secret) do
    described_class.create!(
      grid: grid,
      name: 'test',
      value: '123456'
    )
  end

  describe '#services' do
    it 'returns grid services that are consuming the secret' do
      secret #create
      service = GridService.create!(
        grid: grid,
        name: 'app',
        image_name: 'my/app:latest',
        stateful: false,
        secrets: [
          secret: 'test',
          name: 'test'
        ]
      )
      expect(secret.services).to eq([service])
    end
  end
end
