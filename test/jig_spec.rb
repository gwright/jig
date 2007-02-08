# A Rspec file for Jig
#
#
require File.dirname(__FILE__) + '/../lib/jig'

context "A null jig" do
	setup do
		@jig = Jig.null
	end
	specify "should be an instance of Jig" do
		@jig.should_be_an_instance_of Jig
	end
	specify "should be full" do
		@jig.should_be_full
	end
	specify "should serialize as the null string" do
		@jig.to_s.should == ""
	end
	specify "should test as null" do
		@jig.should_be_null
	end
end

context "A new jig" do
	setup do
		@jig = Jig.new
	end
	specify "should be an instance of Jig" do
		@jig.should_be_an_instance_of Jig
	end
	specify "should have a default gap" do
		@jig.should_have_gap Jig::GAP
	end
	specify "should have only one gap" do
		@jig.gap_count.should == 1
	end
	specify "should serialize as the null string" do
		@jig.to_s.should == ""
	end
end

context "A jig with a single gap named :alpha" do
	setup do
		@jig = Jig.new(:alpha)
	end
	specify 'should have one gap named :alpha' do
		@jig.gap_list.should == [:alpha]
	end
	specify 'should serialize as the null string' do
		@jig.to_s.should == ""
	end
	specify 'should match "beta" when you plug gap :alpha with "beta"' do
		@jig.plug(:alpha, "beta").should 
end

context "A jig with two gaps named :alpha" do
	setup do
		@jig = Jig.new(:alpha, :alpha)
	end
	specify 'should have two gaps named :alpha' do
		@jig.gap_list.shoud == [:alpha, :alpha]
	end
end

# vim: syntax=Ruby
