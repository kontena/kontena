require 'tty-table'

module Kontena
  module Cli
    class TableGenerator

      attr_reader :data
      attr_reader :fields
      attr_reader :header
      attr_reader :row_format_proc, :header_format_proc, :render_options, :render_mode

      DEFAULT_HEADER_FORMAT_PROC = lambda { |header| header.to_s.capitalize }

      DEFAULT_RENDER_OPTS = {padding: [0,2,0,0]}

      module Helper
        def self.included(base)
          if base.respond_to?(:option)
            base.option ['-q', '--quiet'], :flag, "Output the identifying column only"
          end
        end

        def table_generator
          Kontena::Cli::TableGenerator
        end

        def generate_table(array, fields = nil, &block)
          fields ||= self.fields if self.respond_to?(:fields)
          table_generator.new(
            array,
            fields,
            row_format_proc: block_given? ? block.to_proc : nil,
            header_format_proc: lambda { |item| pastel.bold(item.to_s.upcase) },
            render_options: self.respond_to?(:render_options) ? DEFAULT_RENDER_OPTS.merge(self.render_options) : DEFAULT_RENDER_OPTS
          ).render
        end

        def print_table(array, fields = nil, &block)
          output = generate_table(array, fields, &block)
          puts output unless output.strip.empty?
        end
      end

      # @param data [Array<Hash>,Array<Array>] an array of hashes or arrays
      # @param fields [Array] an array of field names found in the data hashes.
      # @param fields [Hash] a hash of field_title => field_name_in_the_data_hash, for example 'Users' => 'user_count'
      # @param fields [NilClass] try to auto detect fields (all fields!) from the data hashes
      # @return [TTY::Table]
      def initialize(data, fields = nil, row_format_proc: nil, header_format_proc: nil, render_options: nil)
        @data = data
        @render_options = render_options || { }
        @render_mode = @render_options.delete(:mode) || :basic
        @row_format_proc = row_format_proc
        @header_format_proc = header_format_proc || DEFAULT_HEADER_FORMAT_PROC
        @fields = parse_fields(fields)
        @header = generate_header(fields || @fields)
      end

      def create_table(header, rows)
        TTY::Table.new(
          header: header,
          rows: rows
        )
      end

      def table
        create_table(header, rows)
      end

      def render
        if data.empty?
          fields.size > 1 ? fields.map(&method(:format_header_item)).join('  ') : ''
        else
          table.render(render_mode, render_options).gsub(/\s+$/, '')
        end
      end

      def format_row(row)
        return row if row_format_proc.nil?
        row_clone = row.dup
        row_format_proc.call(row_clone)
        row_clone
      end

      def format_header_item(field_name)
        header_format_proc.call(field_name)
      end

      def rows
        fields.empty? ? data.map { |row| format_row(row).map(&:values) } : data.map { |row| format_row(row).values_at(*fields) }
      end

      # Collect all the unique keys from the hashes if the data
      # is an array of hashes.
      def detect_fields
        if data.first.respond_to?(:keys)
          data.flat_map(&:keys).uniq
        else
          []
        end
      end

      def parse_fields(fields)
        if fields.nil? || fields.empty?
          detect_fields
        elsif fields.kind_of?(Hash)
          fields.values
        else
          fields
        end
      end

      def generate_header(fields)
        if fields.kind_of?(Hash)
          header = fields.keys
        else
          header = Array(fields)
        end

        if header.size < 2
          nil
        else
          header.map { |head| format_header_item(head) }
        end
      end
    end
  end
end
