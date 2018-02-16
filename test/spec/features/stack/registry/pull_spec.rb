require 'spec_helper'

describe 'stack registry' do
  context 'pull' do
    context 'when the stack does not exist' do
      it 'exits with an error' do
        k = run 'kontena stack registry pull --no-cache kontena/doesnot-exist'
        expect(k.code).not_to be_zero
        expect(k.out).to match /not found/
      end
    end

    context 'when the stack exists' do
      context 'without version number' do
        it 'displays the YAML' do
          k = run! 'kontena stack registry pull --no-cache kontena/ingress-lb'
          expect(k.out.lines.find { |l| l.start_with?('stack: kontena/ingress-lb')}).not_to be_nil
          expect(k.out.lines.find { |l| l.start_with?('variables:')}).not_to be_nil
          expect(k.out.lines.find { |l| l.start_with?('services:')}).not_to be_nil
          expect(k.out.lines.find { |l| l.start_with?('version: 0.1.0')}).to be_nil
        end
      end

      context 'with version number' do
        it 'displays the YAML for that version' do
          k = run! 'kontena stack registry pull --no-cache kontena/ingress-lb:0.1.0'
          expect(k.out.lines.find { |l| l.start_with?('stack: kontena/ingress-lb')}).not_to be_nil
          expect(k.out.lines.find { |l| l.start_with?('variables:')}).not_to be_nil
          expect(k.out.lines.find { |l| l.start_with?('services:')}).not_to be_nil
          expect(k.out.lines.find { |l| l.start_with?('version: 0.1.0')}).not_to be_nil
        end
      end
    end
  end
end
