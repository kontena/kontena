module OutputHelpers
  extend RSpec::Matchers::DSL

  matcher :return_and_output do |expected, *lines|
    supports_block_expectations

    match do |actual|
      stdout = lines.flatten.join("\n") + "\n"

      begin
        expect{@return = actual.call}.to output(stdout).to_stdout
      rescue Exception => error
        @error = error

        return false
      else
        return values_match? expected, @return
      end
    end

    failure_message do |actual|
      if @error
        return @error
      else
        return "expected #{actual} to return #{expected}, but returned #{@return}"
      end
    end
  end
end
