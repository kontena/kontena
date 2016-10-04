module RequirementsHelper

  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def expect_to_require_current_master
      describe "prerequisites" do
        it "should require current master" do
          expect(described_class.requires_current_master?).to be_truthy
        end
      end
    end

    def expect_to_require_current_grid
      describe "prerequisites" do
        it "should require current grid" do
          expect(described_class.requires_current_current_grid?).to be_truthy
        end
      end
    end

    def expect_to_require_current_master_token
      describe "prerequisites" do
        it "should require current master token" do
          expect(described_class.requires_current_current_master_token?).to be_truthy
        end
      end
    end
  end
end
