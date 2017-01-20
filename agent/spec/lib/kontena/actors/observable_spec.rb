describe Kontena::Actors::Observable do
  subject do
    described_class.new
  end

  let :object do
    double(:test)
  end
  let :object2 do
    double(:test2)
  end

  let :observer_class do
    Class.new do
      include Celluloid
      include Kontena::Actors::Observer
      include Kontena::Logging

      def initialize(**observables)
        observe **observables do
          @ready = true
        end
      end

      def [](sym)
        instance_variable_get("@#{sym}")
      end

      def wait
        sleep 0.1 until @ready
      end
    end
  end

  it "does not observe any value if not yet updated", :celluloid => true do
    expect(observer_class.new(object: subject)[:object]).to be_nil
  end

  it "immediately observes an updated value", :celluloid => true do
    subject.update object

    expect(observer_class.new(object: subject)[:object]).to be object
  end

  it "waits for an updated value", :celluloid => true do
    observer = observer_class.new(object: subject)
    wait_future = observer.future.wait

    subject.update object

    Timeout.timeout(1) do
      wait_future.value

      expect(observer[:object]).to be object
    end
  end

  it "waits for two observables", :celluloid => true do
    subject1 = described_class.new
    subject2 = described_class.new

    observer = observer_class.new(object1: subject1, object2: subject2)
    wait_future = observer.future.wait

    subject1.update object
    subject2.update object2

    Timeout.timeout(1) do
      wait_future.value

      expect(observer[:object1]).to be object
      expect(observer[:object2]).to be object2
    end

  end
end
