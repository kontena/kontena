RSpec::Matchers.define_negated_matcher :exit_without_error, :exit_with_error
RSpec::Matchers.define :exit_with_error do

  def supports_block_expectations?
    true
  end

  match do |block|
    begin
      block.call
    rescue SystemExit => e
      @exit_status = e.status
    end
    !@exit_status.nil? && @exit_status == expected_status
  end

  chain :status do |status|
    @expected_status = status
  end

  failure_message do |block|
    "expected block to exit with status #{expected_status} but exit " +
      (@exit_status.nil? ? "was not called" : "status was #{@exit_status}")
  end

  failure_message_when_negated do |block|
    "expected block not to raise SystemExit, got exit with status #{@exit_status}"
  end

  description do
    "expect block to exit #{expected_status.zero? ? "without error" : "with error (status #{expected_status})"}"
  end

  def expected_status
    @expected_status ||= 1
  end
end
