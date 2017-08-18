require_relative '../../../lib/kontena/helpers/wait_helper'

class TestObserver
  include Celluloid
  include Kontena::Observer
  include Kontena::Logging

  attr_reader :observe_state

  def ping

  end

  def test_observe_async(*observables)
    @observe_state = observe(*observables) do |*values|
      @observed_values = values
    end
  end
  def observed?
    !@observed_values.nil?
  end
  def observed_values
    @observed_values
  end
  def observe_ready?
    @observe_state.ready?
  end

  def test_ordering(observable)
    @observed_value = nil
    @observed_values = []
    @ordered = true
    @value = nil
    @observe_state = observe(observable) do |value|
      if @observed_value && @observed_value > value
        warn "unordered value=#{value} after #{@observed_value}"
        @ordered = false
      else
        debug "observed #{@observed_value} -> #{value}"
      end
      @observed_value = value
      @observed_values << value
    end
  end

  def observed_value
    @observed_value
  end
  def ordered?
    @ordered
  end

  def crash
    fail
  end
end

describe Kontena::Observer, :celluloid => true do
  let(:observable_class) { TestObservable }
  let(:observer_class) { TestObserver }

  subject { observer_class.new() }

  it "raises synchronously if given an invalid actor", :celluloid => true, :log_celluloid_actor_crashes => false do
    expect{subject.test_observe_async('foo')}.to raise_error(NoMethodError, /undefined method `add_observer' for "foo":String/)
  end

  context "For a single observable" do
    let(:observable) { observable_class.new }
    let(:object) { double(:test) }

    describe '#unwrap_observable' do
      it 'returns the wrapped object' do
        expect(described_class.unwrap_observable(observable)).to be_a TestObservable
        expect(described_class.unwrap_observable(observable).class).to eq TestObservable
      end
    end

    describe '#observe' do
      it "does not observe any value if not yet updated" do
        subject.test_observe_async(observable)

        expect(subject).to_not be_observed
      end

      it "immediately yields an updated value" do
        observable.update_observable object

        subject.test_observe_async(observable)

        expect(subject).to be_observed
        expect(subject.observed_values).to eq [object]
      end

      it "later yields after updating value" do
        subject.test_observe_async(observable)

        expect(subject).to_not be_observed

        observable.update_observable object

        expect(subject).to be_observed
        expect(subject.observed_values).to eq [object]
      end

      it "crashes if the observable does", :log_celluloid_actor_crashes => false do
        subject.test_observe_async(observable)

        expect{observable.crash}.to raise_error(RuntimeError)

        expect{subject.observed?}.to raise_error(Celluloid::DeadActorError)
      end
    end

    describe '#observe_sync' do
      it 'raises timeout if the observable is not ready', :log_celluloid_actor_crashes => false do
        expect{
          subject.observe(observable, timeout: 0.01)
        }.to raise_error(Timeout::Error, 'timeout after waiting 0.01s until: Observable<TestObservable>')
      end

      it 'immediately returns value if updated' do
        observable.update_observable(object)

        expect(subject.observe(observable)).to eq object

        observable.reset_observable
      end

      it 'blocks until observable without timeout' do
        observable.delay_update(object, delay: 0.5)

        expect(subject.observe(observable)).to eq object
      end

      it 'blocks until observable with timeout' do
        observable.delay_update(object, delay: 0.5)

        expect(subject.observe(observable, timeout: 1.0)).to eq object
      end

      it 'does not lose wait messages' do
        allow(subject.wrapped_object).to receive(:debug) do |msg|
          sleep 0.2
        end

        observable.async.spam_updates(1..1000, duration: 0.5, interval: 0.01, delay: 0.1)

        # XXX: this is likely to be a an old value, because the observable messages queue up,
        # and the first one resumes the waiting task
        expect(subject.observe(observable, timeout: 1.0)).to be_a Integer
      end
    end

    context "Which later updates" do
      let(:object2) { double(:test2) }

      before do
        observable.update_observable object

        subject.test_observe_async(observable)

        expect(subject).to be_observed
        expect(subject.observed_values).to eq [object]
      end

      it "yields with the updated value" do
        observable.update_observable object2

        expect(subject.observed_values).to eq [object2]
      end

      it "does not yield after a reset" do
        observable.reset_observable

        expect(subject.observed_values).to eq [object]
        expect(subject).to_not be_observe_ready
      end
    end
  end

  context "For two observables" do
    let(:observable1) { observable_class.new }
    let(:observable2) { observable_class.new }

    let(:object1) { double(:test1) }
    let(:object2) { double(:test2) }
    let(:object3) { double(:test3) }

    describe '#observe_async' do
      it "yields with both values" do
        observable1.update_observable object1
        observable2.update_observable object2

        subject.test_observe_async(observable1, observable2)

        expect(subject).to be_observed
        expect(subject.observed_values).to eq [object1, object2]
      end

      it "does not yield after a reset" do
        observable1.update_observable object1
        observable2.update_observable object2

        subject.test_observe_async(observable1, observable2)

        expect(subject.observed_values).to eq [object1, object2]

        observable1.reset_observable
        observable2.update_observable object3

        expect(subject.observed_values).to eq [object1, object2]
      end
    end

    describe '#observe_sync' do
      it "returns both values if immediately available" do
        observable1.update_observable object1
        observable2.update_observable object2

        expect(subject.observe(observable1, observable2, timeout: 0.5)).to eq [object1, object2]
      end

      it "returns both values once available" do
        future = subject.future.observe(observable1, observable2, timeout: 0.5)

        observable1.delay_update(object1, delay: 0.1)
        observable2.delay_update(object2, delay: 0.1)

        expect(future.value).to eq [object1, object2]
      end

      it "waits for second value to become available" do
        observable1.update_observable object1

        future = subject.future.observe(observable1, observable2, timeout: 0.5)

        expect(future).to_not be_ready

        observable2.update_observable object2

        expect(future.value).to eq [object1, object2]
      end
    end
  end

  context "For a supervised observer that observes a supervised actor by name" do
    let :supervised_observer_class do
      Class.new do
        include Celluloid
        include Kontena::Observer

        attr_reader :state, :values

        def initialize(actor_name)
          @state = observe(Celluloid::Actor[actor_name]) do |*values|
            @values = values
          end
        end

        def ready?
          @state.ready?
        end

        def crash
          fail
        end
      end
    end

    before :each do
      @observable_actor = Celluloid::Actor[:observable_test] = observable_class.new
      @observer_actor = Celluloid::Actor[:observer_test] = supervised_observer_class.new(:observable_test)

      expect(@observer_actor).to_not be_ready

      @observable_actor.update_observable 1

      expect(@observer_actor).to be_ready
      expect(@observer_actor.values).to eq [1]
    end

    it "crashing allows it to re-observe the existing value immediately after restarting", :log_celluloid_actor_crashes => false do
      expect{@observer_actor.crash}.to raise_error(RuntimeError)
      Kontena::Helpers::WaitHelper.wait_until! { @observer_actor.dead? }

      # simulate supervisor
      @observer_actor = Celluloid::Actor[:observer_test] = supervised_observer_class.new(:observable_test)

      expect(@observer_actor).to be_ready
      expect(@observer_actor.values).to eq [1]
    end

    it "restarts after the observable crashes and waits for it to update", :log_celluloid_actor_crashes => false do
      expect{@observable_actor.crash}.to raise_error(RuntimeError)
      Kontena::Helpers::WaitHelper.wait_until! { @observable_actor.dead? && @observer_actor.dead? }

      # simulate supervisor restart in the wrong order
      expect{supervised_observer_class.new(:observable_test)}.to raise_error(Celluloid::DeadActorError)
      @observable_actor = Celluloid::Actor[:observable_test] = observable_class.new
      @observer_actor = Celluloid::Actor[:observer_test] = supervised_observer_class.new(:observable_test)

      expect(@observer_actor).to_not be_ready

      @observable_actor.update_observable 2

      expect(@observer_actor).to be_ready
      expect(@observer_actor.values).to eq [2]
    end
  end

  context 'for a standalone Observable' do
    let :actor_class do
      ActorClass = Class.new do
        include Celluloid
      end
    end
    let(:standaone_observable_class) { TestObservableStandalone }

    let(:actor) { actor_class.new }
    let(:observable) { standaone_observable_class.new }
    let(:value) { double() }

    describe '#unwrap_observable' do
      it 'returns the object' do
        expect(described_class.unwrap_observable(observable)).to be_a standaone_observable_class
        expect(described_class.unwrap_observable(observable).class).to eq standaone_observable_class
      end
    end

    it 'is observable' do
      observable
      actor.after(0.05) {
        observable.update_observable(value)
      }

      expect(subject.observe(observable, timeout: 1.0)).to eq value
    end
  end
end
