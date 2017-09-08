class TestObservableActor
  include Celluloid
  include Kontena::Observable::Helper
  include Kontena::Logging

  def ping
    debug "ping"
  end

  def crash(msg = nil, delay: nil)
    sleep delay if delay
    if msg
      fail msg
    else
      fail
    end
  end

  def update(value)
    observable.update(value)
  end

  def reset
    observable.reset
  end

  def delay_update(value, delay: )
    after(delay) do
      observable.update(value)
    end
  end

  def spam_updates(values, delay: nil, duration: nil, interval: nil)
    deadline = Time.now + duration if duration

    sleep delay if delay

    for value in values
      break if deadline && Time.now >= deadline

      observable.update(value)

      sleep interval if interval
    end
  end
end

describe Kontena::Observable do
  let(:value) { double(:value) }

  describe '#update' do
    it "rejects a nil update" do
      expect{subject.update nil}.to raise_error(ArgumentError)
    end
  end

  context 'when initialized' do
    it 'is not ready?' do
      expect(subject).to_not be_ready
    end

    it 'is not crashed?' do
      expect(subject).to_not be_crashed
    end

    describe '#get' do
      it 'returns nil' do
        expect(subject.get).to be nil
      end
    end
  end

  context 'when updated' do
    before do
      subject.update value
    end

    it 'is ready?' do
      expect(subject).to be_ready
    end

    it 'is not crashed?' do
      expect(subject).to_not be_crashed
    end

    describe '#get' do
      it 'returns the value' do
        expect(subject.get).to eq value
      end
    end

    context 'when reset' do
      before do
        subject.reset
      end

      it 'is not ready?' do
        expect(subject).to_not be_ready
      end

      it 'is not crashed?' do
        expect(subject).to_not be_crashed
      end

      describe '#get' do
        it 'returns nil' do
          expect(subject.get).to be nil
        end
      end
    end
  end

  context 'when crashed' do
    before do
      subject.crash RuntimeError.new
    end

    it 'is ready?' do
      expect(subject).to be_ready
    end

    it 'is crashed?' do
      expect(subject).to be_crashed
    end

    describe '#update' do
      it "rejects any update" do
        expect{subject.update nil}.to raise_error(RuntimeError)
      end
    end
  end

  context 'registered by an Actor', :celluloid => true do
    let(:registry) { Kontena::Observable.registry }
    let(:observable_actor) { TestObservableActor.new }
    subject { observable_actor.observable }
    let(:observer_actor) { TestObserverActor.new }

    it 'is observable after updating' do
      observable_actor.update(value)

      expect(observer_actor.observe(subject, timeout: 0.0)).to eq value
    end

    it 'is observable before updating' do
      observable_actor.delay_update(value, delay: 0.05)

      expect(observer_actor.observe(subject, timeout: 1.0)).to eq value
    end

    it "propagates crashes to observers and unregisters after crashing" do
      subject

      expect(registry.registered? subject).to be_truthy

      observable_actor.async.crash('test', delay: 0.1)

      expect{observer_actor.observe(subject)}.to raise_error(Kontena::Observer::Error, 'RuntimeError@Kontena::Observable<TestObservableActor>: test')

      expect(registry.registered? subject).to be_falsey
    end

    it "stops notifying any crashed observers", :log_celluloid_actor_crashes => false do
      observer_actor.async.test_observe_async(subject)
      observer_actor.ping

      expect(subject).to be_observed

      expect{observer_actor.crash}.to raise_error(RuntimeError)

      # make sure the observer is really dead
      expect{observer_actor.ping}.to raise_error(Celluloid::DeadActorError)
      expect(observer_actor).to_not be_alive

      subject.update(value)
      expect(subject).to_not be_observed
    end

    it "delivers updates in the right order" do
      observer_actor.async.test_ordering(subject)

      update_count = 150

      observable_actor.spam_updates(1..update_count, interval: false)

      expect(observer_actor.observed_values.last).to eq update_count
      expect(observer_actor.ordered?).to be_truthy
    end

    describe "propagating observed updates" do
      let :chaining_class do
        Class.new do
          include Celluloid
          include Kontena::Observer::Helper

          attr_reader :observable

          def initialize
            @observable = Kontena::Observable.new
          end

          def test_observe_chain(observable)
            observe(observable) do |value|
              @observable.update "chained: " + value
            end
          end

          def ping

          end
        end
      end

      let(:chaining_actor) { chaining_class.new }
      let(:observer_actor) { TestObserverActor.new }

      it "propagates the observed value" do
        chaining_actor.async.test_observe_chain(subject)
        observer_actor.async.test_observe_async(chaining_actor.observable)

        observable_actor.update "test"

        chaining_actor.ping # wait for intermediate actor to handle update
        chaining_actor.ping # wait for intermediate actor to handle update
        observer_actor.ping # wait for observing actor to handle update

        sleep 0.01

        observer_actor.ping # wait for observing actor to handle update

        expect(observer_actor.observed_values).to eq ["chained: test"]
      end
    end
  end

  it "handles concurrent observers", :celluloid => true do
    observer_count = 20
    update_count = 10

    begin
      observable_actor = TestObservableActor.new
      observable = observable_actor.observable

      # setup
      observer_actors = observer_count.times.map {
        TestObserverActor.new
      }

      # start spamming updates while the observer actors are concurrently observing
      future = observable_actor.future.spam_updates(1..update_count, delay: 0.005, interval: 0.001)

      observer_actors.each do |actor|
        actor.async.test_ordering(observable)
        sleep 0.001
      end

      # wait for observable actor to notify all observers
      future.value

      # wait for all observers to observe and update
      observer_actors.each do |actor|
        actor.ping
      end

      # all observers get the final value
      expect(observer_actors.map{|actor| actor.observed_values.last}).to eq [update_count] * observer_count

      # make sure they get the values in order
      expect(observer_actors.map{|actor| actor.ordered?}).to eq [true] * observer_count

      # validate that observer race conditions were triggered
      # some observers observed before the first update, some after
      # this is not a bug in the observable/observer!
      # the spec just didn't hit the desired race condition
      min_first = observer_actors.map{|actor| actor.observed_values.first}.min
      max_first = observer_actors.map{|actor| actor.observed_values.first}.max

      fail "retry" unless min_first == 1 && max_first > 1

    rescue RuntimeError => exc
      retry if exc.message == "retry"
    end
  end
end
