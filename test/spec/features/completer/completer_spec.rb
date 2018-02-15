require 'spec_helper'

describe 'complete' do

  let(:current_master_name) do
    k = run('kontena master current --name')
    if k.code.zero?
      k.out.strip
    else
      nil
    end
  end

  it 'outputs subcommand tree with --subcommand-tree' do
    k = run!('kontena complete --subcommand-tree')
    rows = k.out.split(/[\r\n]+/)
    expect(rows).to include "kontena grid show"
    expect(rows).to include "kontena stack install"
    expect(rows).to include "kontena service restart"
    expect(rows).to include "kontena volume list"
    expect(rows).to include "kontena master user role add"
    expect(rows).not_to include "kontena master user role add foo"
    expect(rows.size > 100).to be_truthy
  end

  it 'can complete subcommands' do
    k = run 'kontena complete kontena'
    rows = k.out.split(/[\r\n]+/)
    expect(rows).to include "stack"
    expect(rows).to include "vault"
    expect(rows).to include "whoami"
  end

  it 'can complete subsubcommands' do
    k = run 'kontena complete kontena stack'
    rows = k.out.split(/[\r\n]+/)
    expect(rows).to include "install"
    expect(rows).to include "deploy"
  end

  it 'can complete subsubsubcommands' do
    k = run 'kontena complete kontena master user'
    rows = k.out.split(/[\r\n]+/)
    expect(rows).to include "invite"
    expect(rows).to include "role"
  end

  it 'can complete subsubsubsubcommands' do
    k = run 'kontena complete kontena master user role'
    rows = k.out.split(/[\r\n]+/)
    expect(rows).to include "add"
    expect(rows).to include "remove"
  end

  context 'master names' do
    let(:masters) { run('kontena master ls -q').out.split(/[\r\n]+/) }

    it 'for master use' do
      k = run 'kontena complete kontena master use'
      rows = k.out.split(/[\r\n]+/).map(&:strip)
      masters.each do |master_name|
        expect(rows).to include master_name unless master_name == current_master_name
      end
      expect(rows).not_to include current_master_name
    end

    it 'can complete master names for master rm' do
      k = run 'kontena complete kontena master rm'
      rows = k.out.split(/[\r\n]+/).map(&:strip)
      masters.each do |master_name|
        expect(rows).to include master_name
      end
    end
  end

  context 'master queries' do
    context 'with current master set' do
      context 'grid names' do
        it 'for use, should not include current grid' do
          k = run 'kontena complete kontena grid use'
          rows = k.out.split(/[\r\n]+/).map(&:strip)
          expect(rows).not_to include "e2e"
        end

        it 'for show, should include current grid' do
          k = run 'kontena complete kontena grid show'
          rows = k.out.split(/[\r\n]+/).map(&:strip)
          expect(rows).to include "e2e"
        end
      end

      it 'can complete node names' do
        node_names = run('kontena node ls -q').out.split(/[\r\n]+/)
        k = run 'kontena complete kontena node show'
        rows = k.out.split(/[\r\n]+/)
        node_names.each do |node_name|
          expect(rows).to include node_name
        end
      end
    end

    context 'without current master set' do
      before(:each) do
        @current_master_name = current_master_name
        run 'kontena master use --clear'
      end

      after(:each) do
        if @current_master_name
          run 'kontena master use ' + @current_master_name
        end
      end

      it 'should return empty' do
        k = run 'kontena complete kontena node show'
        expect(k.out.split(/[\r\n]+/).size).to be_zero
      end
    end
  end
end
