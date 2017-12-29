
describe GridSecret do
  it { should be_timestamped_document }
  it { should have_fields(:name, :encrypted_value).of_type(String).with_options({ encrypted: { random_iv: true } }) }
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

  describe '#encrypted_value' do
    it 'uses random iv' do
      s1 = described_class.create!(
        grid: grid,
        name: 'test1',
        value: '123456'
      )
      s2 = described_class.create!(
        grid: grid,
        name: 'test2',
        value: '123456'
      )
      expect(s1.encrypted_value).not_to eq(s2.encrypted_value)
    end
  end
end
