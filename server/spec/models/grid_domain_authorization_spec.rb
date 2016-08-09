require_relative '../spec_helper'

describe GridDomainAuthorization do
  it { should have_fields(:domain).of_type(String)}
  it { should have_fields(:challenge, :challenge_opts).of_type(Hash) }

  
end