module AsyncMock
  def self.included(cls)
    cls.before do
      # test async blocks by running them sync
      allow_any_instance_of(described_class).to receive(:async_thread) do |&block|
        block.call
      end
    end
  end
end
