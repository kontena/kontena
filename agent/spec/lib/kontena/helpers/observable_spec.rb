describe Kontena::Observable do
  let :observable_class do
    Class.new do
      include Celluloid
      include Kontena::Observable

      def crash
        fail
      end
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

      attr_reader :values

      def initialize(*observables)
        @observables = observables
      end

      def start
        observe *@observables do |*values|
          @values = values
        end
      end

      def ready?
        !@values.nil?
      end

      def wait
        sleep 0.1 until ready?
      end
    end
  end

  it "does not observe any value if not yet updated", :celluloid => true do
    observer = observer_class.new(subject)
    observer.async.start

    # XXX: timing
    expect(observer).to_not be_ready
  end

  it "immediately observes an updated value", :celluloid => true do
    subject.update object

    observer = observer_class.new(subject)
    observer.async.start

    sleep 0.1 # XXX: timing

    expect(observer).to be_ready
    expect(observer.values).to eq [object]
  end

  it "waits for an updated value", :celluloid => true do
    observer = observer_class.new(subject)
    observer.async.start

    wait_future = observer.future.wait

    subject.update object

    wait_future.value(1.0)

    expect(observer).to be_ready
    expect(observer.values).to eq [object]
  end

  it "waits for two observables", :celluloid => true do
    subject1 = observable_class.new
    subject2 = observable_class.new

    observer = observer_class.new(subject1, subject2)
    observer.async.start

    wait_future = observer.future.wait

    subject1.update object
    subject2.update object2

    wait_future.value(1.0)

    expect(observer).to be_ready
    expect(observer.values).to eq [object, object2]
  end

  it "crashes if the observable does", :celluloid => true do
    observer = observer_class.new(subject)
    observer.async.start

    sleep 0.1 # XXX: timing

    expect{subject.crash}.to raise_error(RuntimeError)

    expect{observer.ready?}.to raise_error(Celluloid::DeadActorError)
  end
end
