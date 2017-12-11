require 'openssl'
require 'tmpdir'

describe 'kontena/lb certificates' do
  let(:ssl_subject) do
    OpenSSL::X509::Name.parse "/CN=localhost"
  end
  let(:ssl_key) do
    ssl_key = OpenSSL::PKey::RSA.new(1024)
  end
  let(:ssl_cert) do
    key = ssl_key

    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 2
    cert.subject = ssl_subject
    cert.issuer = cert.subject # self-signed
    cert.public_key = key.public_key
    cert.not_before = Time.now - 60.0
    cert.not_after = Time.now + 300.0 # +5/-1 minute validity

    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = cert
    ef.issuer_certificate = cert

    cert.add_extension(ef.create_extension("basicConstraints","CA:TRUE",true))
    cert.add_extension(ef.create_extension("keyUsage","keyCertSign, cRLSign", true))
    cert.add_extension(ef.create_extension("subjectKeyIdentifier","hash",false))
    cert.sign(key, OpenSSL::Digest::SHA256.new)
    cert
  end

  let(:tmp_path) { Dir.mktmpdir('kontena-cert-test_') }
  let(:cert_path) { File.join(tmp_path, 'cert.pem') }
  let(:key_path) { File.join(tmp_path, 'key.pem') }

  before(:each) do
    File.write(cert_path, ssl_cert.to_pem)
    File.write(key_path, ssl_key.to_pem)

    k = run("kontena certificate import --private-key=#{key_path} #{cert_path}")
    expect(k.code).to eq(0), k.out

    with_fixture_dir('stack/certificates') do
      k = run('kontena stack install -v certificate=localhost kontena-lb.yml')
      expect(k.code).to eq(0), k.out
    end

    sleep 5 # XXX: wait for lb service to be ready...
  end

  after(:each) do
    run("kontena stack rm --force cert-test")
    run("kontena certificate rm --force localhost")
    run("rm -rf #{tmp_path}")
  end

  it 'deploys the certificate to the LB for https' do
    k = run("curl --cacert #{cert_path} https://localhost")
    expect(k.code).to eq(0), k.out
    expect(k.out).to include 'whoami-1.cert-test.e2e.kontena.local'
  end
end
