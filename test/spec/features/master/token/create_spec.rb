require 'spec_helper'

describe 'token create' do
  it ' creates a token with description' do
    k = run!('kontena master token create --description tokendescriptiontest --id')
    token_id = k.out.strip
    k = run('kontena master token list')
    expect(k.out).to match /tokendescriptiontest/
    k = run('kontena master token show %s' % token_id)
    expect(k.out).to match /description: tokendescriptiontest/
  end
end
