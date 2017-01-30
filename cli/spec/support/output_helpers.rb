module OutputHelpers
  extend RSpec::Matchers::DSL

  matcher :return_and_output do |expected, *lines|
    supports_block_expectations

    match do |block|
      stdout = lines.flatten.join("\n") + "\n"

      begin
        expect{@return = block.call}.to output(stdout).to_stdout
      rescue Exception => error
        @error = error

        return false
      else
        return values_match? expected, @return
      end
    end

    failure_message do |block|
      if @error
        return @error
      else
        return "expected #{block} to return #{expected}, but returned #{@return}"
      end
    end
  end

  matcher :output_table do |lines|
    supports_block_expectations

    match do |block|
      stdout = Regexp.new('^' + lines.map{|fields| fields.join('\s+')}.join('\n') + '\n$', Regexp::MULTILINE)


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

  matcher :exit_with_error do |*lines|
    supports_block_expectations

    match do |block|
      stderr = lines.flatten.join("\n") + "\n"

      @exit = nil

      wrapper = proc {
        begin
          block.call
        rescue SystemExit => exc
          @exit = exc
        end
      }

      begin
        expect{wrapper.call}.to output(stderr).to_stderr
      rescue Exception => error
        @error = error

        return false
      else
        return @exit != nil
      end
    end

    failure_message do |block|
      return @error if @error
      return "did not exit" unless @exit
    end
  end

end
