require 'spec_helper'

describe 'stack registry' do
  context 'search' do
    it 'shows a list of stacks' do
      k = run! 'kontena stack registry search'
      expect(k.out.lines.size > 20).to be_truthy
      expect(k.out).to match(/kontena\/ingress-lb/)
    end

    it 'shows a list of stacks filtered by name' do
      k = run! 'kontena stack registry search kontena/ingress-lb'
      expect(k.out).to match(/VERSION/)
      expect(k.out.lines.find { |l| l.start_with?('kontena/ingress-lb') }).not_to be_nil
    end

    it 'shows a list of stacks filtered by description' do
      k = run! 'kontena stack registry search balancer'
      expect(k.out.lines.find { |l| l.start_with?('kontena/ingress-lb') }).not_to be_nil
    end
  end
end
