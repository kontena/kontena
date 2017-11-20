require 'spec_helper'

describe 'external-registry add' do
  after(:each) do
    run 'kontena external-registry rm --force registry.domain.com'
  end

  it 'adds a new external-registry' do
    k = run 'kontena external-registry add -u foo -e foo@no.email -p secret https://registry.domain.com/'
    expect(k.code).to eq(0)
    k = run 'kontena external-registry ls'
    expect(k.out.include?('registry.domain.com'))
  end

  it 'adds a new external-registry without protocol' do
    k = run 'kontena external-registry add -u foo -e foo@no.email -p secret registry.domain.com'
    expect(k.code).to eq(0)
    k = run 'kontena external-registry ls'
    expect(k.out.include?('registry.domain.com'))
  end

  it 'requires -u option' do
    k = run 'kontena external-registry add https://foo.domain.com'
    expect(k.code).not_to eq(0)
    expect(k.out.include?("'-u' is required"))
  end

  it 'requires -e option' do
    k = run 'kontena external-registry -u user add https://foo.domain.com'
    expect(k.code).not_to eq(0)
    expect(k.out.include?("'-e' is required"))
  end

  it 'requires -p option' do
    k = run 'kontena external-registry -u user -e foo@email.com add https://foo.domain.com'
    expect(k.code).not_to eq(0)
    expect(k.out.include?("'-p' is required"))
  end
end
