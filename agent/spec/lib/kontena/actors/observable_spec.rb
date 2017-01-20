describe Kontena::Actors::Observable do
  subject do
    Kontena::Actors::Observable.new
  end

  let :object do
    double(:test)
  end

  let :observer_class do
    Class.new do
      include Celluloid
      include Kontena::Actors::Observer
      include Kontena::Logging

      attr_accessor :object

      def initialize(observable)
        observe object: observable
      end

      def poll
        until @object
          sleep 0.1
        end

        return @object
      end
    end
  end

  it "does not observe any value if not yet updated", :celluloid => true do
    expect(observer_class.new(subject).object).to be_nil
  end

  it "immediately observes an updated value", :celluloid => true do
    subject.update object

    expect(observer_class.new(subject).object).to be object
  end

  it "waits for an updated value", :celluloid => true do
    observer = observer_class.new(subject)
    wait_future = observer.future.poll

    subject.update object

    Timeout.timeout(1) do
      expect(wait_future.value).to be object
    end
  end
end
