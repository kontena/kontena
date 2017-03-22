describe Kontena::Observable do
  let :observable_class do
    Class.new do
      include Celluloid
      include Kontena::Observable
    end
  end

  subject do
    observable_class.new
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
      include Kontena::Observer

      def initialize(**observables)
        observe **observables do
          @ready = true
        end
      end

      def [](sym)
        instance_variable_get("@#{sym}")
      end

      def ready?
        @ready
      end

      def wait
        sleep 0.1 until @ready
      end
    end
  end

  it "does not observe any value if not yet updated", :celluloid => true do
    observer = observer_class.new(object: subject)

    expect(observer[:object]).to be_nil
    expect(observer).to_not be_ready
  end

  it "immediately observes an updated value", :celluloid => true do
    subject.update object

    observer = observer_class.new(object: subject)

    expect(observer[:object]).to be object
    expect(observer).to be_ready
  end

  it "waits for an updated value", :celluloid => true do
    observer = observer_class.new(object: subject)

    wait_future = observer.future.wait

    subject.update object

    wait_future.value(1.0)

    expect(observer[:object]).to be object
    expect(observer).to be_ready
  end

  it "waits for two observables", :celluloid => true do
    subject1 = observable_class.new
    subject2 = observable_class.new

    observer = observer_class.new(object1: subject1, object2: subject2)

    wait_future = observer.future.wait

    subject1.update object
    subject2.update object2

    wait_future.value(1.0)

    expect(observer[:object1]).to be object
    expect(observer[:object2]).to be object2
  end
end
