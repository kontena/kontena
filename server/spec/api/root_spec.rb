require_relative '../spec_helper'

describe '/' do
  it 'should return success' do
    get '/', nil, {}
    expect(response.status).to eq(200)
  end

  it 'should return server version' do
    get '/', nil, {}
    expect(json_response['version']).not_to be_nil
  end
end
