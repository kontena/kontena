require 'spec_helper'

describe 'stack registry' do
  context 'show' do
    context 'when the stack does not exist' do
      it 'exits with an error' do
        k = run 'kontena stack registry show kontena/doesnot-exist'
        expect(k.code).not_to be_zero
        expect(k.out).to match /not found/
      end
    end

    context 'when the stack exists' do
      it 'shows information about the stack' do
        k = run!('kontena stack registry show kontena/ingress-lb')
        expect(k.out).to match /description:/
        expect(k.out).to match /latest_version:/
        expect(k.out).to match /versions:/
      end
    end
  end
end
