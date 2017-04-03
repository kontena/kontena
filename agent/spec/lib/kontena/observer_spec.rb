require_relative '../../../lib/kontena/helpers/wait_helper'

describe Kontena::Observer do
  let :observable_class do
    Class.new do
      include Celluloid
      include Kontena::Observable

      def crash
        fail
      end
    end
  end

  let :observer_class do
    Class.new do
      include Celluloid
      include Kontena::Observer

      attr_reader :state, :values

      def initialize(*observables)
        @state = observe(*observables) do |*values|
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

  it "raises synchronously if given an invalid actor", :celluloid => true, :log_celluloid_actor_crashes => false do
    expect{observer_class.new('foo')}.to raise_error(NoMethodError, /undefined method `add_observer' for "foo":String/)
  end

  context "For a single observable" do
    let(:observable) { observable_class.new }

    subject { observer_class.new(observable) }

    let(:object) { double(:test) }

    it "does not observe any value if not yet updated", :celluloid => true do
      expect(subject).to_not be_ready
    end

    it "immediately yields an updated value", :celluloid => true do
      observable.update_observable object

      subject

      expect(subject).to be_ready
      expect(subject.values).to eq [object]
    end

    it "later yields after updating value", :celluloid => true do
      subject

      expect(subject).to_not be_ready

      observable.update_observable object

      expect(subject).to be_ready
      expect(subject.values).to eq [object]
    end

    it "crashes if the observable does", :celluloid => true, :log_celluloid_actor_crashes => false do
      expect{observable.crash}.to raise_error(RuntimeError)

      expect{subject.ready?}.to raise_error(Celluloid::DeadActorError)
    end

    context "Which later updates" do
      let(:object2) { double(:test2) }

      before do
        observable.update_observable object

        expect(subject).to be_ready
        expect(subject.values).to eq [object]
      end

      it "yields with the updated value", :celluloid => true do
        observable.update_observable object2

        expect(subject.values).to eq [object2]
      end

      it "does not yield after a reset", :celluloid => true do
        observable.reset_observable

        expect(subject.values).to eq [object]
        expect(subject).to_not be_ready
      end
    end
  end

  context "For two observables", :celluloid => true do
    let(:observable1) { observable_class.new }
    let(:observable2) { observable_class.new }

    subject { observer_class.new(observable1, observable2) }

    let(:object1) { double(:test1) }
    let(:object2) { double(:test2) }
    let(:object3) { double(:test3) }

    it "yields with both values" do
      observable1.update_observable object1
      observable2.update_observable object2

      expect(subject).to be_ready
      expect(subject.values).to eq [object1, object2]
    end

    it "does not yield after a reset" do
      observable1.update_observable object1
      observable2.update_observable object2

      expect(subject.values).to eq [object1, object2]

      observable1.reset_observable
      observable2.update_observable object3

      expect(subject.values).to eq [object1, object2]
    end
  end

  context "For a supervised observer that observes a supervised actor by name", :celluloid => true do
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
end
