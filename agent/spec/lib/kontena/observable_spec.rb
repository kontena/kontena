describe Kontena::Observable, :celluloid => true do
  let :observable_class do
    TestObservable = Class.new do
      include Celluloid
      include Kontena::Observable

      def crash
        fail
      end

      def delay_update(value, delay: )
        after(delay) do
          update_observable value
        end
      end

      def spam_updates(enum, interval: false)
        enum.each do |value|
          sleep interval if interval
          update_observable value
        end
      end

      def ping

      end
    end
  end

  let :observer_class do
    Class.new do
      include Celluloid
      include Kontena::Observer

      attr_reader :state, :value, :first

      def initialize(observable, start: true)
        @observable = observable
        @first = nil
        @ordered = true
        self.start if start
      end

      def start
        @state = observe(@observable) do |value|
          @first ||= value
          if @value && @value > value
            warn "unordered value=#{value} after #{@value}"
            @ordered = false
          else
            debug "observed #{@value} -> #{value}"
          end
          @value = value
        end
      end

      def ping

      end

      def ready?
        !@value.nil?
      end
      def ordered?
        @ordered
      end

      def crash
        fail
      end
    end
  end

  subject { observable_class.new }

  let(:object) { double(:test) }

  describe '#update_observable' do
    it "rejects a nil update", :log_celluloid_actor_crashes => false do
      expect{subject.update_observable nil}.to raise_error(ArgumentError)
    end
  end

  context 'when initialized' do
    it 'is not observable?' do
      expect(subject).to_not be_observable
    end

    describe '#observable_value' do
      it 'returns nil' do
        expect(subject.observable_value).to be nil
      end
    end

    describe '#wait_observable' do
      it 'raises timeout' do
        expect{subject.wait_observable!(timeout: 0.01)}.to raise_error(Timeout::Error, /until: Observable<TestObservable> is ready/)
      end
    end
  end

  context 'when updated' do
    before do
      subject.update_observable object
    end

    it 'is observable?' do
      expect(subject).to be_observable
    end

    describe '#observable_value' do
      it 'returns the value' do
        expect(subject.observable_value).to eq object
      end
    end

    describe '#wait_observable' do
      it 'returns the value' do
        expect(subject.wait_observable!(timeout: 0.01)).to eq object
      end
    end

    context 'when reset' do
      before do
        subject.reset_observable
      end

      it 'is not observable?' do
        expect(subject).to_not be_observable
      end

      describe '#observable_value' do
        it 'returns nil' do
          expect(subject.observable_value).to be nil
        end
      end
    end
  end

  it "stops notifying any crashed observers", :log_celluloid_actor_crashes => false do
    observer = observer_class.new(subject)
    expect(subject.observers).to_not be_empty

    expect{observer.crash}.to raise_error(RuntimeError)

    # make sure the observer is really dead
    expect{observer.ping}.to raise_error(Celluloid::DeadActorError)
    expect(observer).to_not be_alive
    subject.ping

    subject.update_observable(object)
    expect(subject.observers).to be_empty
  end

  it "delivers updates in the right order" do
    observer = observer_class.new(subject)

    update_count = 150

    subject.spam_updates(1..update_count, interval: false)

    expect(observer.value).to eq update_count
    expect(observer.ordered?).to be_truthy
  end

  it "handles concurrent observers" do
    observer_count = 20
    update_count = 10

    # setup
    observers = observer_count.times.map {
      observer_class.new(subject, start: false)
    }

    observers.each do |obs|
      obs.async.start
    end

    # run updates sync while the observers are starting
    subject.spam_updates(1..update_count, interval: 0.001)

    # wait for observable to notify all observers
    subject.ping

    # wait for all observers to observe and update
    observers.each do |obs| obs.ping end
    observers.each do |obs| obs.ping end # and maybe a second round for the async update

    # all observers got the final value
    expect(observers.map{|obs| obs.value}).to eq [update_count] * observer_count

    # this is potentially racy, but it's important, or this spec doesn't test what it should
    expect(observers.map{|obs| obs.first}.max).to be > 1

    # also expect this...
    expect(observers.map{|obs| obs.ordered?}).to eq [true] * observer_count
  end

  describe '#wait_observable' do
    it 'blocks until observable' do
      subject.delay_update(object, delay: 0.5)

      # NOTE: the class must include the WaitHelper, so that it uses Celluloid#sleep
      #       if the wait_until! uses Kernel#sleep and blocks the actor thread,
      #       then this spec will fail, because the delayed update doesn't have a chance to run
      expect(subject.wait_observable!(timeout: 1.0)).to eq object
    end
  end

  context "For chained observables" do
    let :chaining_class do
      Class.new do
        include Celluloid
        include Kontena::Observer
        include Kontena::Observable

        def initialize(observable)
          @state = observe(observable) do |value|
            update_observable "chained: " + value
          end
        end

        def ping

        end
      end
    end

    describe '#observe => #update_observable' do
      it "propagates the observed value" do
        chaining = chaining_class.new(subject)
        observer = observer_class.new(chaining)

        subject.update_observable "test"

        chaining.ping # wait for intermediate actor to handle update

        expect(observer).to be_ready
        expect(observer.value).to eq "chained: test"
      end
    end
  end
end
