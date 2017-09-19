require 'kontena/cli/stacks/yaml/validator_v3'
require 'kontena/cli/stacks/yaml/custom_validators/affinities_validator'

describe Kontena::Cli::Stacks::YAML::Validations::CustomValidators::AffinitiesValidator do

  let(:errors) { Hash.new }

  it 'accepts valid affinity' do
    subject.validate('affinity', ['foo==bar'], [], errors)
    expect(errors.size).to eq(0)
  end

  it 'accepts valid soft affinity' do
    subject.validate('affinity', ['foo==~bar'], [], errors)
    expect(errors.size).to eq(0)
  end

  it 'does not accept invalid affinity' do
    subject.validate('affinity', ['foo=bar'], [], errors)
    expect(errors.size).to eq(1)
  end
end
