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

  it "raises synchronously if given an invalid actor", :celluloid => true do
    expect{observer_class.new('foo')}.to raise_error(NoMethodError, /undefined method `add_observer' for "foo":String/)
  end

  context "For a single observable" do
    let :observable do
      observable_class.new
    end

    subject { observer_class.new(observable) }

    let(:object) { double(:test) }

    it "does not observe any value if not yet updated", :celluloid => true do
      expect(subject).to_not be_ready
    end

    it "immediately yields an updated value", :celluloid => true do
      observable.update object

      subject

      expect(subject).to be_ready
      expect(subject.values).to eq [object]
    end

    it "later yields after updating value", :celluloid => true do
      subject

      expect(subject).to_not be_ready

      observable.update object

      expect(subject).to be_ready
      expect(subject.values).to eq [object]
    end

    it "crashes if the observable does", :celluloid => true do
      expect{observable.crash}.to raise_error(RuntimeError)

      expect{subject.ready?}.to raise_error(Celluloid::DeadActorError)
    end

    context "Which later updates" do
      let(:object2) { double(:test2) }

      before do
        observable.update object

        expect(subject).to be_ready
        expect(subject.values).to eq [object]
      end

      it "yields with the updated value", :celluloid => true do
        observable.update object2

        expect(subject.values).to eq [object2]
      end

      it "does not yield after a reset", :celluloid => true do
        observable.reset

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
      observable1.update object1
      observable2.update object2

      expect(subject).to be_ready
      expect(subject.values).to eq [object1, object2]
    end

    it "does not yield after a reset" do
      observable1.update object1
      observable2.update object2

      expect(subject.values).to eq [object1, object2]

      observable1.reset
      observable2.update object3

      expect(subject.values).to eq [object1, object2]
    end
  end

end
