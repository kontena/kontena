describe 'certificate import' do
  include FixturesHelper
  let(:cert_pem) { fixture('certificates/test/cert.pem')}
  let(:key_pem) { fixture('certificates/test/key.pem')}
  let(:key_rsa_pem) { fixture('certificates/test/key_rsa.pem')}
  let(:ca_pem) { fixture('certificates/test/ca.pem')}

  before(:all) do
    with_fixture_dir('certificates/test') do
      k = run('kontena certificate import --private-key key.pem --chain ca.pem cert.pem')
      expect(k.code).to eq(0), k.out
    end
  end
  after(:all) do
    run("kontena certificate rm --force test")
  end

  it 'exports certificate bundle' do
    k = run("kontena certificate export test")
    expect(k.code).to eq(0), k.out

    out = k.out.gsub("\r\n", "\n")

    expect(out).to include(cert_pem)
    expect(out).to include(key_rsa_pem)
    expect(out).to include(ca_pem)
  end

  it 'exports certificate' do
    k = run("kontena certificate export --certificate test")
    expect(k.code).to eq(0), k.out

    expect(k.out.gsub("\r\n", "\n")).to eq(cert_pem)
  end

  it 'exports private key' do
    k = run("kontena certificate export --private-key test")
    expect(k.code).to eq(0), k.out

    expect(k.out.gsub("\r\n", "\n")).to eq(key_rsa_pem) # gets converted
  end

  it 'exports chain' do
    k = run("kontena certificate export --chain test")
    expect(k.code).to eq(0), k.out

    expect(k.out.gsub("\r\n", "\n")).to eq(ca_pem)
  end

  it 'logs audit' do
    k = run("kontena certificate export --chain test")
    expect(k.code).to eq(0), k.out

    k = run('kontena grid audit-log --lines=10')
    expect(k.code).to eq(0), k.out

    expect(k.out).to match /Certificate.*export/
  end
end
