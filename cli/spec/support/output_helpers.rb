module OutputHelpers
  extend RSpec::Matchers::DSL

  matcher :return_and_output do |expected, *lines|
    supports_block_expectations

    match do |block|
      @expected = expected
      stdout = lines.flatten.join("\n") + "\n"

      begin
        expect{@return = block.call}.to output(stdout).to_stdout
      rescue Exception => error
        @error = error

        return false
      else
        return values_match? @expected, @return
      end
    end

    failure_message do |block|
      if @error
        return @error
      else
        return "expected #{block} to return #{@expected}, but returned #{@return}"
      end
    end
  end

  matcher :output_table do |lines|
    supports_block_expectations

    match do |block|
      @errors = []

      @expected = lines
      begin
        @real = CaptureStdoutLines.capture(block)
      rescue Exception => error
        @errors = [error.to_s]
        return false
      end

      if @expected_header
        @expected.unshift(@expected_header)
      elsif @no_header
        nil
      else
        @real.shift
      end

      if @expected.size == @real.size
        line = 0
        @real.zip(@expected) do |real, expected|
          line += 1
          fields = real.split(/\s{2,}/)
          unless values_match?(fields, expected)
            @errors << [
              "on line #{line}:",
              " expected: #{expected}",
              " received: #{fields}",
            ].join("\n")
          end
        end
      else
        @errors << "expected #{@expected.size} lines but got #{@real.size} lines instead:\n"
          + " Expected:\n#{@expected.map(&:inspect).join("\n")}"
          + " Received:\n#{@real.map(&:inspect).join("\n")}"
      end
      @errors.empty?
    end

    failure_message do |block|
      @errors.join "\n"
    end

    chain :with_header do |header|
      @expected_header = header
    end

    chain :without_header do
      @no_header = true
    end
  end

  matcher :output_lines do |lines|
    supports_block_expectations

    match do |block|
      stdout = lines.flatten.join("\n") + "\n"

      begin
        expect{@return = block.call}.to output(stdout).to_stdout
      rescue Exception => error
        @error = error

        return false
      else
        return true
      end
    end

    failure_message do |block|
      return @error
    end
  end

  module CaptureStdoutLines
    def self.capture(block)
      capture = StringIO.new
      original = $stdout
      $stdout = capture
      block.call
      capture.string.split(/[\r\n]/)
    ensure
      $stdout = original
    end
  end
end
