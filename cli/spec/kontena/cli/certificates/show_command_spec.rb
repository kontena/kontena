require 'kontena/cli/certificate/show_command'

describe Kontena::Cli::Certificate::ShowCommand do
  include ClientHelpers
  include OutputHelpers
  include FixturesHelpers

  let(:subject) { described_class.new("") }

  let(:certificate) {
    {
      'id' => 'test-grid/test.example.com',
      'subject' => 'test.example.com',
      'valid_until' => '2017-12-14T13:34:00.000+00:00',
      'alt_names' => [],
      'auto_renewable' => true,
    }
  }

  before do
    allow(client).to receive(:get).with('certificates/test-grid/test.example.com').and_return(certificate)
  end

  it "outputs the certificate info" do
    expect{subject.run(['test.example.com'])}.to output_lines([
      'test-grid/test.example.com:',
      '  subject: test.example.com',
      "  valid_until: '2017-12-14T13:34:00.000+00:00'",
      '  alt_names: []',
      '  auto_renewable: true',
    ])
  end

  context 'with certificate alt_names' do
    let(:certificate) {
      {
        'id' => 'test-grid/test.example.com',
        'subject' => 'test.example.com',
        'valid_until' => '2017-12-14T13:34:00.000+00:00',
        'alt_names' => [
            'test2.example.com',
        ],
        'auto_renewable' => true,
      }
    }

    it "outputs the certificate info" do
      expect{subject.run(['test.example.com'])}.to output_lines([
        'test-grid/test.example.com:',
        '  subject: test.example.com',
        "  valid_until: '2017-12-14T13:34:00.000+00:00'",
        '  alt_names:',
        '  - test2.example.com',
        '  auto_renewable: true',
      ])
    end
  end
end
