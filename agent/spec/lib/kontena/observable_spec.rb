class TestObservable
  include Celluloid
  include Kontena::Observable

  def ping

  end

  def crash(delay: nil)
    sleep delay if delay
    fail
  end

  def delay_update(value, delay: )
    after(delay) do
      update_observable value
    end
  end

  def spam_updates(values, delay: nil, duration: nil, interval: nil)
    deadline = Time.now + duration if duration

    sleep delay if delay

    for value in values
      break if deadline && Time.now >= deadline

      update_observable(value)

      sleep interval if interval
    end
  end
end

class TestObservableStandalone
  include Kontena::Observable
end

describe Kontena::Observable, :celluloid => true do
  let(:observable_class) { TestObservable }
  let(:observer_class) { TestObserver }

  subject { observable_class.new }
  let(:observer) { observer_class.new }
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
    observer.test_observe_async(subject)

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
    observer.test_ordering(subject)

    update_count = 150

    subject.spam_updates(1..update_count, interval: false)

    expect(observer.observed_values.last).to eq update_count
    expect(observer.ordered?).to be_truthy
  end

  it "handles concurrent observers" do
    observer_count = 20
    update_count = 10

    # setup
    observers = observer_count.times.map {
      observer_class.new
    }

    observers.each do |observer|
      observer.async.test_ordering(subject)
    end

    # run updates sync while the observers are starting
    subject.spam_updates(1..update_count, interval: 0.001)

    # wait for observable to notify all observers
    subject.ping

    # wait for all observers to observe and update
    observers.each do |obs| obs.ping end
    observers.each do |obs| obs.ping end # and maybe a second round for the async update

    # all observers got the final value
    expect(observers.map{|obs| obs.observed_values.last}).to eq [update_count] * observer_count

    # some observers only observed after the first update
    # this is potentially racy, but it's important, or this spec doesn't test what it should
    expect(observers.map{|obs| obs.observed_values.first}.max).to be > 1

    # also expect this...
    expect(observers.map{|obs| obs.ordered?}).to eq [true] * observer_count
  end

  context 'for a standalone Observable' do
    let :actor_class do
      ActorClass = Class.new do
        include Celluloid
      end
    end

    let(:actor) { actor_class.new }
    let(:subject) { TestObservableStandalone.new }
    let(:value) { double() }

    it 'is observable' do
      subject
      actor.after(0.05) {
        subject.update_observable(value)
      }

      expect(observer.observe(subject, timeout: 1.0)).to eq value
    end
  end

  context "For chained observables" do
    let :chaining_class do
      Class.new do
        include Celluloid
        include Kontena::Observer
        include Kontena::Observable

        def test_observe_chain(observable)
          @observe_state = observe(observable) do |value|
            update_observable "chained: " + value
          end
        end

        def ping

        end
      end
    end

    describe '#observe => #update_observable' do
      it "propagates the observed value" do
        chaining = chaining_class.new
        chaining.test_observe_chain(subject)
        observer = observer_class.new
        observer.test_observe_async(chaining)

        subject.update_observable "test"

        chaining.ping # wait for intermediate actor to handle update

        expect(observer).to be_observe_ready
        expect(observer.observed_values).to eq ["chained: test"]
      end
    end
  end
end
