require_relative '../spec_helper'
require 'kontena/command'

describe Kontena do
  let(:subject) do
    class TestCommand < Kontena::Command

      callback_matcher 'test', 'foo'

      parameter 'PARAM', 'Single param'
      parameter '[PLIST] ...', 'A number of params'
      option '--flag', :flag, 'Flag'
      option '--foo', 'FOO', 'Option'

      def execute
      end

      def plist_size
        plist_list.size
      end
    end

    TestCommand
  end

  after(:each) do
    Object.send(:remove_const, :TestCommand) if Object.const_defined?(:TestCommand)
  end

  describe '#new' do
    it 'works with the classic .new syntax' do
      cmd = subject.new(['hello'])
      expect(cmd.flag?).to be_nil
      expect(cmd.param).to be_nil
      expect(cmd.plist_list).to be_empty
    end

    it 'works with a more mutations like syntax' do
      cmd = subject.new(flag: true, foo: 'bar', param: 'param', plist_list: ['foo', 'bar'])
      expect(cmd.plist_size).to eq 2
      expect(cmd.flag?).to be_truthy
      expect(cmd.foo).to eq 'bar'
      expect(cmd.param).to eq 'param'
      expect(cmd.plist_list.first).to eq 'foo'
      expect(cmd.plist_list.last).to eq 'bar'
    end

    it 'multi value param can be set without _list' do
      cmd = subject.new(flag: true, foo: 'bar', param: 'param', plist: ['foo', 'bar'])
      expect(cmd.plist_list.first).to eq 'foo'
      expect(cmd.plist_list.last).to eq 'bar'
    end
  end
end

