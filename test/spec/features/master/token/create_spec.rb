require 'spec_helper'

describe 'token create' do
  it ' creates a token with description' do
    k = run!('kontena master token create --description "token description test --id')
    token_id = k.out.strip
    k = run('kontena master token list')
    expect(k.out).to match /token description test/
    k = run('kontena master token show %s' % token_id)
    expect(k.out).to match /description: token description test/
  end
end
