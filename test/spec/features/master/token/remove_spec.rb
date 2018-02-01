require 'spec_helper'

describe 'token remove' do
  it ' creates a token with description' do
    k = run!('kontena master token create --id')
    token_id = k.out.strip
    run!('kontena master token remove %s' % token_id)
    k = run('kontena master token list -q')
    expect(k.out.lines).not_to include token_id
  end
end
