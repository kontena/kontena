describe 'certificate import' do
  after(:each) do
    run("kontena certificate rm --force test")
  end

  it 'imports certificates from file' do
    with_fixture_dir('certificates/test') do
      k = run('kontena certificate import --private-key key.pem --chain ca.pem cert.pem')
      expect(k.code).to eq(0), k.out
    end

    k = run("kontena certificate list -q")
    expect(k.code).to eq(0), k.out
    expect(k.out.lines.map{|l| l.strip}).to include 'test'

    k = run("kontena certificate show test")
    expect(k.code).to eq(0), k.out
    expect(k.out.lines.map{|l| l.strip}).to include 'subject: test'
  end
end
