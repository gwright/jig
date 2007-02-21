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
		@jig.should_have_gap :___
	end
	specify "should have only one gap" do
		@jig.gap_count.should == 1
	end
	specify "should serialize as the null string" do
		@jig.to_s.should == ""
	end
	specify "should not have a default gap after plug(:alpha)" do
		@jig.plug(Jig::Gap.new(:alpha)).should_not_have_gap :___
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
		@jig.plug(:alpha, "beta").to_s.should == "beta"
	end
end

context "A jig with two gaps named :alpha" do
	setup do
		@jig = Jig.new(:alpha, :alpha)
	end
	specify 'should have two gaps named :alpha' do
		@jig.gap_list.should == [:alpha, :alpha]
	end
	specify 'should match "hoho" when you plug gap :alpha with "ho"' do
		@jig.plug(:alpha, "ho").to_s.should == "hoho"
	end
end

context "A jig with two gaps named :alpha and :beta" do
	setup do
		@jig = Jig.new(:alpha, :beta)
	end
	specify 'should have two gaps named :alpha, :beta' do
		@jig.gap_list.should == [:alpha, :beta]
	end
end

context "A jig constructed by parsing 'a<:alpha:>b'" do
	setup do
		@jig = Jig.parse "a<:alpha:>b"
	end
	specify 'should have one gap named :alpha' do
		@jig.gap_list.should == [:alpha]
	end
	specify 'should match "ab"' do
		@jig.should_match "ab"
	end
end

context "A jig constructed by parsing 'a<:alpha,beta:>b'" do
	setup do
		Xjig = Class.new(Jig)
		Xjig.enable :xml
		@jig = Xjig.parse "a<:alpha,beta:>b"
	end
	specify 'should have one gap named :beta' do
		@jig.gap_list.should == [:beta]
	end
	specify 'should match "ab"' do
		@jig.should_match "ab"
	end
	specify 'should match "aalpha=1b" after plug :beta with 1' do
		@jig.plug(:beta, 1).should_match "aalpha=1b"
	end
end

# vim: syntax=Ruby
