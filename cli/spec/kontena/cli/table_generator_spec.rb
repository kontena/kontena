require 'kontena/cli/table_generator'
require 'kontena/command'
require 'kontena/cli/common'

describe Kontena::Cli::TableGenerator do
  let(:data) { [{'a' => 'a1', 'b' => 'b1', 'c' => 'c1'}, {'a' => 'a2', 'b' => 'b2', 'c' => 'c2'}] }

  context Kontena::Cli::TableGenerator::Helper do
    let(:klass) { Class.new(Kontena::Command) }

    it 'adds the quiet option' do
      klass.include(described_class)
      expect(klass.recognised_options.first.flag?).to be_truthy
      expect(klass.recognised_options.first.long_switch).to eq '--quiet'
      expect(klass.recognised_options.first.switches).to include '-q'
      expect(klass.recognised_options.first.description).to match (/identifying column/)
    end

    context 'with the helper included' do

      let(:subject) { klass.new([]) }

      before(:each) do
        klass.include(Kontena::Cli::Common)
        klass.include(described_class)
      end

      it 'responds to print_table' do
        expect(subject).to respond_to(:print_table)
      end

      it 'responds to generate_table' do
        expect(subject).to respond_to(:print_table)
      end

      context '#print_table' do

        include OutputHelpers

        it 'outputs a table from an array and a list of fields' do
          expect{subject.print_table(data, ['a', 'b'])}.to output_table([
            ['a1', 'b1'],
            ['a2', 'b2']
          ]).with_header(['A', 'B'])
        end

        it 'outputs a table without a header when only one field' do
          expect{subject.print_table(data, ['a'])}.to output_table([
            ['a1'],
            ['a2']
          ]).without_header
        end

        it 'outputs nothing when table with no data and only one field' do
          expect{subject.print_table({}, ['a'])}.to output(/\A\z/).to_stdout
        end

        it 'tries to read the fields from #fields method when none given' do
          expect(subject).to receive(:fields).and_return(['a', 'b'])
          expect{subject.print_table(data)}.to output_table([
            ['a1', 'b1'],
            ['a2', 'b2']
          ]).with_header(['A', 'B'])
        end

        it 'tries to read render options from #render_options method' do
          expect(subject).to receive(:render_options).and_return(mode: :ascii, border: { separator: '|' })
          expect{subject.print_table(data)}.to output(/\|/).to_stdout
        end
      end
    end
  end

  let(:klass) { described_class }

  context 'with an array of hashes' do
    context 'given a list of fields' do
      it 'collects the fields listed from the hashes and capitalizes the field names' do
        subject = klass.new(data, ['a', 'b'])
        expect(subject).to receive(:create_table).with(['A', 'B'], [['a1', 'b1'], ['a2', 'b2']]).and_return(true)
        subject.table
      end
    end

    context 'given no list of fields' do
      it 'uses all fields found in the data and creates field names for the header' do
        data.each { |hash| expect(hash).to receive(:keys).and_call_original }
        subject = klass.new(data)
        expect(subject).to receive(:create_table).with(['A', 'B', 'C'], [['a1', 'b1', 'c1'], ['a2', 'b2', 'c2']]).and_return(true)
        subject.table
      end
    end

    context 'given one field' do
      it 'creates a table of one column without a header (quiet mode)' do
        subject = klass.new(data, 'a')
        expect(subject).to receive(:create_table).with(nil, [['a1'], ['a2']]).and_return(true)
        subject.table
      end
    end

    context 'given a field mapping' do
      it 'uses the field keys as header titles and values as data field keys' do
        subject = klass.new(data, { 'First' => 'a', 'Third' => 'c' })
        expect(subject).to receive(:create_table).with(['First', 'Third'], [['a1', 'c1'], ['a2', 'c2']]).and_return(true)
        subject.table
      end
    end

    context 'row formatting' do
      it 'calls the format proc for all rows of data' do
        format_proc = proc do |row|
          row['d'] = [row['b'], row['c']].join('/')
        end
        expect(format_proc).to receive(:call).exactly(2).times.and_call_original
        subject = klass.new(data, ['a', 'd'], row_format_proc: format_proc)
        expect(subject).to receive(:create_table).with(['A', 'D'], [['a1', 'b1/c1'], ['a2', 'b2/c2']]).and_return(true)
        subject.table
      end
    end
  end
end
