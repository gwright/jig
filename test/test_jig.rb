require 'jig/html'
require 'test/unit'

module JigTest
	def assert_similar(a,b, mess="")
		assert_match(a, b, mess)
	end

	def assert_not_similar(a, b, mess="")
		assert_not_match(a, b, mess)
	end
end


class Jig
	class TestJig < Test::Unit::TestCase
		include JigTest
		def test_creation
			# empty jigs and gaps
			assert_instance_of(Symbol, Jig::GAP)
			assert_instance_of(Jig, Jig.new)
			assert(!Jig.new.full?)
			assert((Jig.new << 'full').full?)

			# rendering of empty jigs and gaps
			assert_equal("", Jig.new.to_s)
			assert_equal("", Jig.new(:__gap).to_s)
			assert_equal("", Jig.new(Jig::GAP).to_s)

			# testing ==
			assert_equal(Jig.new(GAP).to_s, Jig.new(Jig::GAP).to_s, 'equality via string conversion')
			assert_equal(Jig.new(GAP), Jig.new(Jig::GAP), 'equality via Jig#==')

			# strings, no gaps
			assert_kind_of(Jig, Jig.new("a", "c"))
			assert_equal("ac", Jig.new("a", "c").to_s)

			# gaps surrounding string
			assert_equal("string", Jig.new("string").to_s)
			assert_equal("string", Jig.new("string", Jig::GAP).to_s)
			assert_equal("string", Jig.new(Jig::GAP, "string").to_s)
			assert_equal("string", Jig.new(Jig::GAP, "string", Jig::GAP).to_s)

			# strings surrounding gaps
			assert_kind_of(Jig, Jig.new("a", GAP, "c"))
			assert_kind_of(String, Jig.new("a", GAP, "c").to_s)
			assert_equal("ac", Jig.new("a", GAP, "c").to_s)

			# gap invariance
			assert_similar(Jig.new(:alpha, "a", :beta), Jig.new(:beta, "a", :alpha), "gap name invariance")
			assert_not_equal(Jig.new(:alpha, "a", :beta), Jig.new(:beta, "a", :alpha), "gap name invariance")
			assert_similar(Jig.new(:alpha, :beta, "a"), Jig.new(:beta, "a"), "gap repetition invariance")
			assert_not_equal(Jig.new(:alpha, :beta, "a"), Jig.new(:beta, "a"), "gap repetition invariance")

			# multiple gaps
			assert_equal("ABC", Jig.new(:alpha, :beta, :gamma).plug(:alpha, "A").plug(:beta, "B").plug(:gamma, "C").to_s, "three gaps")

			# creation with lambdas
			assert_equal("abc", Jig.new( lambda { "abc" }).to_s)
			assert_not_equal(Jig.new( lambda { "abc" }), Jig.new( lambda { "abc" }))
			assert_match(Jig.new( lambda { "abc" }), Jig.new( lambda { "abc" }))
			abc = lambda { "abc" }
			assert_equal(Jig.new(abc), Jig.new(abc))
			assert_match(Jig.new(abc), Jig.new(abc))
			assert_equal("abc", Jig.new(:alpha, lambda { "abc" }).to_s)
			assert_equal("123abc", Jig.new("123", :alpha, lambda { "abc" }).to_s)
			assert_equal("wow", Jig.new { "wow" }.to_s, 'lambda as block to new')
			assert_equal("argblock", Jig.new("arg") { "block" }.to_s, 'args and lambda as block to new')
			assert_equal("arg1arg2block", Jig.new("arg1", "arg2") { "block" }.to_s, 'args and lambda as block to new')

			# creation with arrays
			assert_equal(%Q{abc}, Jig.new(["a", "b", "c"]).to_s)
			assert_equal(%Q{abc}, Jig.new("a", ["b"], "c").to_s)

			# Hash is OK
			assert_nothing_raised(ArgumentError) {Jig.new('a' => 'b')}
			assert_nothing_raised(ArgumentError) {Jig.new("a", 'c'=>'d')}

			# Hash checks
			assert_equal(%Q{ a="b"}, Jig.new('a' => 'b').to_s, 'create from Hash')
			assert_equal(%Q{ a="b" c="d"}, Jig.new('a' => 'b', 'c' => 'd').to_s, 'create from Hash, 2 items')
			assert_equal(%Q{ a="b"}, Jig.new(GAP, 'a' => 'b').to_s, 'hash and gap')
			assert_equal("", Jig.new('a' => GAP).to_s, 'attribute suppression')

			assert_nothing_raised(ArgumentError, 'hash OK with #new') { Jig.new(:div, "first", {'a' => 'b'}, "third") }
			assert_equal(%Q{first a="b"third}, Jig.new(:div, "first", {'a' => 'b'}, "third").to_s)
		end

		def setup
			@a1c = Jig.new("a", :alpha, "c")
			@d2f = Jig.new("d", :beta, "f")
			@a1c2e = Jig.new("a", :alpha, "c", :beta, "e")
		end

		def test_comparisons
			assert_equal("abc", Jig["abc"].to_s)
			assert_match(Jig["abc"], Jig["a","b", "c"])
			assert_not_equal(Jig["abc"], Jig["a",:g1, "b", :g2, "c"])
			assert_match(Jig["abc"], Jig["a",:g1, "b", :g2, "c"])
		end

		def test_plugging
			# plugging gaps
			assert_equal("ac", Jig.new("a", "c").plug("b").to_s)
			assert_kind_of(Jig, Jig.new("a", GAP, "c").plug("b"))
			assert_kind_of(String, Jig.new("a", GAP, "c").plug("b").to_s)
			assert_equal("abc", Jig.new("a", GAP, "c").plug("b").to_s)
			assert_equal("XaX", Jig.new(GAP, "a", GAP).plug("X").to_s)

			# using << instead of #plug
			assert_equal("ac", (Jig.new("a", "c") << ("b")).to_s)
			assert_kind_of(Jig, Jig.new("a", GAP, "c") << ("b"))
			assert_kind_of(String, (Jig.new("a", GAP, "c")<<("b")).to_s)
			assert_equal("abc", (Jig.new("a", GAP, "c")<<("b")).to_s)
			assert_equal("XaX", (Jig.new(GAP, "a", GAP)<<("X")).to_s)

			# named gaps
			assert_equal(Jig.new(:alpha).to_s, Jig.new(:beta).to_s)
			assert_equal(Jig.new("a", :alpha).to_s, Jig.new("a", :beta).to_s)
			assert_equal(Jig.new("a", :alpha).to_s, Jig.new(:beta, "a").to_s)

			# plugging named gaps
			assert_similar(@a1c, Jig.new("a", :alpha, :beta).plug(:beta, "c"))
			assert_equal("a", (Jig.new("a", :alpha, :beta) << [:beta, "c"]).to_s)
			assert_similar(@a1c, (Jig.new("a", :alpha, :beta) << [:beta, "c"] << {:beta, "c"} ))
			assert_equal("abc", (Jig.new("a", :alpha, :beta) << [:beta, "c"] << {:beta, "c"}  << {:alpha, "b"} ).to_s)
			assert_equal("a", (Jig.new("a", :alpha, :beta) << { GAP, "c"}).to_s)

			# plugging hashs
			assert_equal(%Q{ a="b"}, Jig.new('a' => :alpha).plug(:alpha, "b").to_s, 'plugging an attribute')
			assert_equal(%Q{ a="b"}, Jig.new('a' => :alpha).plug(:alpha, lambda { "b" }).to_s, 'plugging an attribute with a proc')
			assert_equal(%Q{}, Jig.new('a' => :alpha).plug(:alpha, lambda { nil }).to_s, 'plugging an attribute with a proc returning nil')
			assert_equal(%Q{}, Jig.new({'a',GAP}).plug(lambda { nil }).to_s, 'plugging an attribute with a proc returning nil')

			# plugging  gaps with other jigs
			assert_equal(%Q{abc}, Jig.new("a", GAP, "c").plug(Jig.new("b")).to_s, 'pluging gap with string Jig')
			assert_equal(%Q{ac}, Jig.new("a", :alpha, "c").plug(Jig.new("b")).to_s, 'pluging non-existant gap')
			assert_not_equal(%Q{abc}, Jig.new("a", :alpha, "c").plug(Jig.new("b")).to_s, 'pluging non-existant gap')
			assert_equal(%Q{ac}, Jig.new("a", :alpha, "c").plug(Jig.new(:beta)).to_s, 'pluging gap with a gap')
			assert_not_equal(%Q{abc}, Jig.new("a", :alpha, "c").plug(Jig.new(:beta)).plug("b").to_s, 'pluging gap with a gap')
			assert_equal(%Q{ac}, Jig.new("a", :alpha, "c").plug(:alpha, Jig.new(:beta)).to_s, 'pluging gap with a gap')
			assert_not_equal(%Q{abc}, Jig.new("a", :alpha, "c").plug(:alpha, Jig.new(:beta)).to_s, 'pluging gap with a gap')
			assert_equal(%Q{b}, Jig.new(:beta).plug(:beta, "b").to_s, '')
			assert_equal(%Q{}, Jig.new(:beta).plug(:alpha, "b").to_s, '')
			assert_equal(%Q{b}, Jig.new(:beta).plug(:beta, Jig[:alpha, "b"]).to_s )
			assert_equal(%Q{abc}, Jig.new("a", :alpha, "c").plug(:alpha, Jig.new(:beta)).plug(:beta, "b").to_s, 'pluging gap with a gap')

			# implicit plugs
			assert_equal(%Q{abc}, (Jig.new("a", GAP, "c") << Jig.new(GAP) << "b").to_s, 'implicit names: plugging gap with a gap')
			assert_equal(%Q{abc}, (Jig.new("a", Jig::GAP, "c") << Jig.new(Jig::GAP) << "b").to_s, 'implicit names: plugging gap with a gap')
			assert_equal(%Q{abc}, (Jig.new("a", Jig::GAP, "c") << Jig.new << "b").to_s, 'implicit names: plugging gap with a gap')
		end

		def test_array
			assert_equal(%Q{ab}, (Jig.new << ["a", "b"]).to_s)
			assert_equal(%Q{ab}, (Jig.new << [["a", "b"]]).to_s)
			assert_equal(%Q{ab}, (Jig.new << { GAP => ["a", "b"]}).to_s)
			assert_equal(%Q{}, (Jig.new << {:alpha, ["b"]}).to_s)
			assert_equal(%Q{}, (Jig.new << { :alpha => "b" }).to_s)
			assert_equal(%Q{b}, (Jig.new << { GAP => Jig[:alpha, "b"] }).to_s)
			assert_equal(%Q{ab}, (Jig.new << { GAP => Jig[:alpha, "b"] } << { :alpha => "a" } ).to_s)
			#assert_equal(%Q{cb}, (Jig.new << Jig[:alpha, "b"] << {:alpha, "c"}).to_s)
			assert_equal(%Q{cb}, (Jig.new << Jig[:alpha, "b"] << {:alpha => "c"}).to_s)
			assert_equal(%Q{cb}, ((Jig.new << Jig[:alpha, "b"]).plug(:alpha,"c")).to_s)
			assert_equal(%Q{b}, (Jig.new(:alpha) << {:alpha, "b"} << {:alpha, "c"}).to_s)
			assert_equal(%Q{cb}, (Jig.new << Jig.new(:alpha, "b") << {:alpha, "c"}).to_s)
			assert_equal(%Q{cb}, (Jig.new.plug(GAP, Jig[:alpha, "b"]) << {:alpha, "c"}).to_s)
		end

		def test_element
			# element construction
			@div = "<div></div>\n"
			assert_equal(@div, Jig.element.to_s, 'default element as "div"')

			assert_equal(@div, Jig.element(:div).to_s)
			assert_equal(@div, Jig.element(:div, GAP).to_s)
			assert_equal(@div, Jig.element(:div, Jig::GAP).to_s)
			assert_equal(@div, Jig.element(:div, Jig.new).to_s)

			@div2 = "<div>inside</div>\n"
			assert_equal(@div2, Jig.element(:div, "inside").to_s)
			assert_equal(@div2, Jig.element(:div, "in", "side").to_s)

			# element with attributes
			@div_empty = "<div></div>\n"
			@div_1attr= %Q{<div a="b"></div>\n}
			@div_1attrfilled= %Q{<div a="b">inside</div>\n}
			@div_1attrfilled2= %Q{<div a="b">insidealso</div>\n}
			assert_not_equal(@div_empty, Jig.element(:div, 'a' => 'b').to_s)
			assert_equal(@div_1attr, Jig.element(:div, 'a' => 'b').to_s)
			assert_equal(@div_1attrfilled, Jig.element(:div, {'a' => 'b'}, "inside").to_s)
			assert_equal(@div_1attrfilled, Jig.element(:div, {'a' => 'b'}) { "inside" }.to_s)
			assert_equal(@div_1attrfilled, Jig.element(:div, {'a' => 'b'}, lambda { "inside" } ).to_s)
			assert_equal(@div_1attrfilled2, (Jig.element(:div, {'a' => 'b'}, lambda { "inside" } ) { "also" }).to_s)

			#assert_raise(ArgumentError, 'hash only as first argument') { Jig.element(:div, "first", {'a' => 'b'}, "third") }
		end

		def test_method_missing
			assert_equal(Jig.div, Jig.element(:div))
			assert_equal(Jig.div(GAP), Jig.element(:div, GAP))
			assert_equal(Jig.div(Jig::GAP), Jig.element(:div, Jig::GAP))
			assert_equal(Jig.div(Jig.new), Jig.element(:div, Jig.new))

			assert_equal(Jig.div_, Jig.div)

			@div2 = "<div>inside</div>\n"
			assert_equal(@div2, Jig.element(:div, "inside").to_s)
			assert_equal(@div2, Jig.element(:div, "in", "side").to_s)

			# element with block
			assert_equal(@div2, (Jig.element(:div) {"inside"}).to_s)

			assert_equal(@div2, Jig.div("inside").to_s)
			assert_equal(@div2, Jig.div("in", "side").to_s)

			# div with attributes
			@div_empty = "<div></div>\n"
			@div_1attr= %Q{<div a="b"></div>\n}
			@div_1attrfilled= %Q{<div a="b">inside</div>\n}
			@div_1attrfilled2= %Q{<div a="b">insidealso</div>\n}
			assert_not_equal(@div_empty, Jig.div( 'a' => 'b').to_s)
			assert_equal(@div_1attr, Jig.div( 'a' => 'b').to_s)
			assert_equal(@div_1attrfilled, Jig.div( {'a' => 'b'}, "inside").to_s)
			assert_equal(@div_1attrfilled, Jig.div( {'a' => 'b'}) { "inside" }.to_s)
			assert_equal(@div_1attrfilled, Jig.div( {'a' => 'b'}, lambda { "inside" } ).to_s)
			assert_equal(@div_1attrfilled2, (Jig.div( {'a' => 'b'}, lambda { "inside" } ) { "also" }).to_s)
		end

		def test_more_plugging
			@div = "<div>abc</div>\n"
			@jdiv = Jig.new("<div>abc</div>\n")
			assert_equal(@div, @jdiv.to_s)
			assert_match(@jdiv, Jig.div << "abc")
			assert_match(@jdiv, Jig.div("abc"))
			assert_match(@jdiv, Jig.div { "abc" })

			@divp = "<div><p></p>\n</div>\n"
			@pdiv = "<p><div></div>\n</p>\n"
			@jdivp = Jig.new("<div><p></p>\n</div>\n")
			@jpdiv = Jig.new("<p><div></div>\n</p>\n")
			assert_equal(@divp, @jdivp.to_s)
			assert_equal(@pdiv, @jpdiv.to_s)
			assert_similar(@jdivp, (Jig.div << Jig.p))
			assert_similar(@jpdiv, Jig.p << Jig.div)

			@full = %Q{<div a="b">inside</div>\n}
			@full_jig = Jig.new(%Q{<div a="b">inside</div>\n})
			assert_equal(@full, @full_jig.to_s)
			assert_match(@full_jig, Jig.div('a' => 'b') { "inside" })
			assert_match(@full_jig, Jig.div({'a' => 'b'}, "inside"))
		end

		def test_eid
			@div = %r{<div id="[^"]*"></div>\n}
			@input = %r{<input id="\w*"></input>}
			@jig_div_id = Jig.div_with_id
			@jig_input = Jig.input
			assert_match(@div, @jig_div_id.to_s)
			assert_raise(RuntimeError,'eid reassignment') { @jig_div_id.eid = "foo" }
			assert_match(@input, Jig.input.to_s)
			assert_not_equal(Jig.li_with_id.to_s, Jig.li_with_id.to_s)
		end

		def test_misc
			#assert_raise(ArgumentError, 'attribute must be string') { Jig.div('a' => :gap) << Jig.p }
			#assert_raise(ArgumentError) { ((Jig.div('a' => GAP) << Jig.p).to_s) }

			assert_equal( "ab", (Jig.new(:alpha, :beta) << {:alpha => 'a', :beta => 'b'}).to_s)
			assert_equal( "<div></div>\n", (Jig.div).to_s)
			assert_not_equal( "ab", Jig.div.plug("ab").to_s)
			assert_equal( "<div>ab</div>\n", Jig.div.plug("ab").to_s)

			#assert_equal( %Q{<div a="b">ab</div>\n}, Jig.div("a" => "b").to_s)
			assert_equal( %Q{<div a="b">foo</div>\n}, Jig.div("a" => "b").plug("foo").to_s)

			# test plug nil
			# test plug with Hash
		end
	end

	class MoreJig < Test::Unit::TestCase
		include JigTest

		def test_001_identities
			# empty jigs and gaps
			assert_instance_of(Symbol, Jig::GAP,	'GAP constant')
			assert_instance_of(Jig, Jig.new,		'EMPTY constant')
			assert_instance_of(Jig, Jig::Null,		'BLANK constant')
			assert_similar(Jig.new(GAP), (Jig.new), 'manual construction of an empty jig')
			assert_equal(Jig.new(GAP), Jig.new, 								'manual construction of an empty jig')
			assert_not_same(Jig.new(GAP), Jig.new, 						'manual construction of an empty jig is unique')

			assert_instance_of(Jig, Jig.new,			'empty construction')
			assert_instance_of(Jig, Jig.null,				'blank construction')
			assert_similar(Jig.new, Jig::Null,'blank construction similar to BLANK' )
			#assert_not_equal(Jig.new, Jig.new)

			assert_equal(0, Jig::Null.gap_count,	'blank construction has no gaps')
			assert_equal(1, Jig.new.gap_count,		'empty construction has a gap')
			assert_equal("", Jig::Null.to_s,			'blank shows as empty string')
			assert_equal("", Jig.new.to_s,				'empty shows as empty string')

			assert_similar(Jig.new(:alpha), Jig.new,		"gap names don't affect string values")
			assert_not_equal(Jig.new(:alpha), Jig.new,						"gap names define equality")
		end

		def test_002_creation

			# strings, no gaps
			assert_kind_of(Jig, Jig.new("a", "c"))
			assert_equal("ac", Jig.new("a", "c").to_s)

			# gaps surrounding string
			assert_equal("string", Jig.new("string").to_s)
			assert_equal("string", Jig.new("string", Jig::GAP).to_s)
			assert_equal("string", Jig.new(Jig::GAP, "string").to_s)
			assert_equal("string", Jig.new(Jig::GAP, "string", Jig::GAP).to_s)

			# strings surrounding gaps
			assert_kind_of(Jig, Jig.new("a", :gap, "c"))
			assert_kind_of(String, Jig.new("a", :gap, "c").to_s)
			assert_equal("ac", Jig.new("a", :gap, "c").to_s)

			# gap invariance
			assert_not_equal(Jig.new(:alpha, "a", :beta), Jig.new(:beta, "a", :alpha), "gap name affects equality")
			assert_not_equal(Jig.new(:alpha, :beta, "a"), Jig.new(:beta, "a"), "two gaps are not the same as one")
			assert_similar(Jig.new(:alpha, :beta, "a"), Jig.new(:beta, "a"), "gaps don't affect output")

		end

		def test_003_plugging

			assert_similar(Jig.new("X"), Jig.new(:gap).plug(:gap, "X"), 'jig with just a gap')
			assert_not_equal(Jig.new("X"), Jig.new(:gap1, :gap2).plug(:gap1, "X"), 'jig with just a gap')
			assert_similar(Jig.new("X"), Jig.new(:gap1, :gap2).plug(:gap1, "X"), 'jig with just a gap')
			assert_not_equal(Jig.new("X"), Jig.new(:gap1, :gap2).plug(:gap2, "X"), 'jig with just a gap')
			assert_similar(Jig.new("X"), Jig.new(:gap1, :gap2).plug(:gap2, "X"), 'jig with just a gap')
			assert_similar(Jig.new("XY"), Jig.new(:gap1, :gap2).plug(:gap1, "X").plug(:gap2, "Y"), 'jig with just a gap')
			assert_similar(Jig.new("XY"), Jig.new(:gap1, :gap2).plug(:gap1, "X").plug(:gap2, "Y"), 'jig with just a gap')

			# plugging gaps with strings
			#assert_raise(RuntimeError, 'no gap available') { Jig.new("a", "c").plug(:gap, "b") }
			assert_nothing_raised(RuntimeError) { Jig.new("a", "c").plug(:gap, "b") }
			assert_equal("(X)", Jig.new("(", :gap, ")").plug(:gap, "X").to_s)
			assert_equal("X()", Jig.new(:gap, "(", ")").plug(:gap, "X").to_s)
			assert_equal("()X", Jig.new("(", ")", :gap).plug(:gap, "X").to_s)

			# method_missing
			assert_equal("Aa", Jig.new("A", GAP, "a").to_s)
			assert_equal("AXa", Jig.new("A", GAP, "a").plug(GAP, "X").to_s)
			#assert_equal(Jig.new("A", GAP, "a"), Jig.a)
			#assert_not_equal(Jig.new("A", :gap, "a"), Jig.a)


		end
		def test_004_jig_plugging

			@X = Jig.new("X")
			assert_similar(Jig.new("-X"), Jig.new("-", :gap).plug(:gap, "X"))
			@X = Jig.new("X", GAP, "x")
			assert_not_equal(	Jig.new("-Xx"), 					Jig.new("-", :gap).plug(:gap, @X), 'remaining gap')
			assert_not_equal(	Jig.new("-X", :gap, "x"),	Jig.new("-", :gap).plug(:gap, @X), 'GAP != :gap')
			assert_similar(    	Jig.new("-","X", GAP, "x"), 	Jig.new("-", :gap).plug(:gap, @X), 'GAP == GAP')

			assert_similar(	Jig.new("abXx"), 					Jig.new("a", "b", :gap).plug(:gap, @X), 'gap in the middle')
			assert_similar(	Jig.new("aXxb"), 					Jig.new("a", :gap, "b").plug(:gap, @X), 'gap in the middle')
			assert_similar(	Jig.new("Xxab"), 					Jig.new(:gap, "a", "b").plug(:gap, @X), 'gap at the end')

			# Plug at the end with one item fill
			@one = Jig.new("X")
			assert_similar(	Jig.new("abX"), 					Jig.new("a", "b", :gap).plug(:gap, @one), 'gap in the middle')
			assert_similar(	Jig.new("aXb"), 					Jig.new("a", :gap, "b").plug(:gap, @one), 'gap in the middle')
			assert_similar(	Jig.new("Xab"), 					Jig.new(:gap, "a", "b").plug(:gap, @one), 'gap at the end')

			@onetwo = Jig.new(:gap1, :gap2).plug(:gap1, "1").plug(:gap2, "2")
			assert_similar(	Jig.new("12"), 	@onetwo, 'constructed node')
			assert_similar(	Jig.new("ab12"), 					Jig.new("a", "b", :gap).plug(:gap, @onetwo), 'gap at the end')
			assert_similar(	Jig.new("a12b"), 					Jig.new("a", :gap, "b").plug(:gap, @onetwo), 'gap in the middle')
			assert_similar(	Jig.new("12ab"), 					Jig.new(:gap, "a", "b").plug(:gap, @onetwo), 'gap at the beginning')
		end

		def setup
			@a1c = Jig.new("a", :alpha, "c")
			@d2f = Jig.new("d", :beta, "f")
			@a1c2e = Jig.new("a", :alpha, "c", :beta, "e")
		end

		def test_plugging
			# plugging gaps
			assert_kind_of(Jig, Jig.new("a", GAP, "c").plug("b"))
			assert_kind_of(String, Jig.new("a", GAP, "c").plug("b").to_s)
			assert_equal("abc", Jig.new("a", GAP, "c").plug("b").to_s)
			assert_equal("XaX", Jig.new(GAP, "a", GAP).plug("X").to_s)

			# using << instead of #plug
			assert_nothing_raised(RuntimeError) { Jig.new("a", "c") << ("b") }
			assert_kind_of(Jig, Jig.new("a", GAP, "c") << ("b"))
			assert_kind_of(String, (Jig.new("a", GAP, "c")<<("b")).to_s)
			assert_equal("abc", (Jig.new("a", GAP, "c")<<("b")).to_s)
			assert_equal("XaX", (Jig.new(GAP, "a", GAP)<<("X")).to_s)

			# named gaps
			assert_equal(Jig.new(:alpha).to_s, Jig.new(:beta).to_s)
			assert_equal(Jig.new("a", :alpha).to_s, Jig.new("a", :beta).to_s)
			assert_equal(Jig.new("a", :alpha).to_s, Jig.new(:beta, "a").to_s)

			# plugging named gaps
			assert_equal(@a1c, Jig.new("a", :alpha, :beta).plug(:beta, "c"))
			assert_equal("ac", (Jig.new("a", :alpha, :beta) << { :beta, "c"}).to_s)
			assert_equal("ac", (Jig.new("a", :alpha, :beta) << { :alpha, "c"}).to_s)

			# plugging hashs
			assert_equal(%Q{ a="b"}, Jig.new('a' => :a).plug(:a, "b").to_s, 'plugging an attribute')
			assert_equal(%Q{ a="b"}, Jig.new('a' => :a).plug(:a, lambda { "b" }).to_s, 'plugging an attribute with a proc')
			assert_equal(%Q{}, Jig.new('a' => :a).plug(:a, lambda { nil }).to_s, 'plugging an attribute with a proc returning nil')
			assert_equal(%Q{}, Jig.new({'a',:a}).plug(lambda { nil }).to_s, 'plugging an attribute with a proc returning nil')

			# plugging  gaps with other jigs
			assert_equal(%Q{abc}, Jig.new("a", GAP, "c").plug(Jig.new("b")).to_s, 'pluging gap with string Jig')
			assert_nothing_raised(RuntimeError, 'pluging non-existant gap') { Jig.new("a", :alpha, "c").plug(Jig.new("b")).to_s }
			assert_equal(%Q{ac}, Jig.new("a", :alpha, "c").plug(:alpha, Jig.new(:beta)).to_s, 'pluging gap with a gap')
			assert_not_equal(%Q{abc}, Jig.new("a", :alpha, "c").plug(:alpha, Jig.new(:beta)).to_s, 'pluging gap with a gap')
			assert_equal(%Q{b}, Jig.new(:beta).plug(:beta, "b").to_s, '')
			assert_equal(%Q{abc}, Jig.new("a", :alpha, "c").plug(:alpha, Jig.new(:beta)).plug(:beta, "b").to_s, 'pluging gap with a gap')

			# implicit plugs
			assert_equal(%Q{abc}, (Jig.new("a", GAP, "c") << Jig.new(GAP) << "b").to_s, 'implicit names: plugging gap with a gap')
			assert_equal(%Q{abc}, (Jig.new("a", Jig::GAP, "c") << Jig.new(Jig::GAP) << "b").to_s, 'implicit names: plugging gap with a gap')
			assert_equal(%Q{abc}, (Jig.new("a", Jig::GAP, "c") << Jig.new << "b").to_s, 'implicit names: plugging gap with a gap')

		end
	end

	class MultipleGaps < Test::Unit::TestCase
		include JigTest

		def test_001
			#assert_similar( Jig.new("X-X"), Jig.new(:gap, "-", :gap).plug(:gap, "X"))
			assert_similar( Jig.new("-X-X-"), Jig.new("-", :gap, "-", :gap, "-").plug(:gap, "X"))
		end

		def test_002
			assert_similar( Jig.p, Jig.p)
			assert_equal( Jig.p, Jig.p)
			#assert_same( Jig.p, Jig.p)
		end

		def test_003
			assert_similar(Jig.new("abc"), Jig.new("a") + Jig.new("b") + Jig.new("c"))
			assert_similar(Jig.new("abc"), Jig.new << Jig[Jig.new("a"), Jig.new("b"), Jig.new("c")])
			assert_similar(Jig.new("abc"), Jig.new << Jig[Jig.new("a"), GAP, Jig.new("c")] << "b")
		end

		def test_addition
			assert_equal(Jig.new(Jig.div, Jig.div), (Jig.div + Jig.div))
		end

		def test_misc
			#assert_raise(ArgumentError, 'attribute must be string') { Jig.div('a' => :gap) << Jig.p }
			#assert_raise(ArgumentError) { ((Jig.div('a' => GAP) << Jig.p).to_s) }

			assert_equal( "ab", (Jig.new(:alpha, :beta) << {:alpha => 'a', :beta => 'b'}).to_s)
			assert_equal( "<div></div>\n", (Jig.div).to_s)
			assert_not_equal( "ab", Jig.div.plug("ab").to_s)
			assert_equal( "<div>ab</div>\n", Jig.div.plug("ab").to_s)

			assert_equal( %Q{<div a="b"></div>\n}, Jig.div("a" => "b").to_s)
			assert_equal( %Q{<div a="b">foo</div>\n}, Jig.div("a" => "b").plug("foo").to_s)
			assert_equal( %Q{<div a="foo"></div>\n}, Jig.div("a" => :a).plug(:a, "foo").to_s)
			assert_equal( %Q{<div>bar</div>\n}, Jig.div("a" => nil).plug("bar").to_s)
			assert_equal( %Q{<div a="">bar</div>\n}, Jig.div("a" => "").plug("bar").to_s)
			assert_equal( %Q{<div a="foo">bar</div>\n}, Jig.div("a" => :a).plug("bar").plug(:a, "foo").to_s)

			assert_equal( %Q{<div></div>\n}, Jig.div(nil).to_s)
		end

		def test_string_as_jig
			assert_equal("foo", Jig.new("foo").to_s)
			assert_equal("XfooY", Jig.new("X", :f, "Y").plug(:f, "foo").to_s)
			assert_equal("XfooY", Jig.new("X", :f, "Y").plug({:f, "foo"}).to_s)
			assert_equal("XfooY", Jig.new("X", :f, "Y").plug({:f, Jig.new("foo")}).to_s)
			assert_equal("XfooY", Jig.new("X", :f, :g, "Y").plug({:f, Jig.new("foo")}).to_s)
			assert_equal("XXC", Jig.new(:a, "X", :b, "X", :c).plug(:b, Jig.new(:b1, :b2)).plug(:c, "C").to_s)
			assert_equal("Xfoo!gooY", Jig.new("X", :f, "!", :g, "Y").plug(:f, Jig.new("foo")).plug(:g, Jig.new("goo")).to_s)
			assert_equal("Xfoo!gooY", Jig.new("X", :f, "!", :g, "Y").plug({:f, Jig.new("foo"), :g, Jig.new("goo")}).to_s)
			assert_equal("XfoogooY", Jig.new("X", :f, :g, "Y").plug({:f, Jig.new("foo"), :g, Jig.new("goo")}).to_s)
		end

		def test_1105
			assert_equal("xyzyx", (Jig.new("x", GAP, "x") * [Jig.new("y", GAP, "y")]).plug("z").to_s)
		end

		def test_attribute_with_gap
			j1 = Jig.new("a", :gap1, "b")
			j2 = Jig.form( :onsubmit => j1 )
			assert_equal("<form onsubmit=\"ab\"></form>\n", j2.to_s)
			assert_equal("<form onsubmit=\"ab\"></form>\n", j2.plug(:gap1, "X").to_s)
		end

		def xtest_depth
			a = Jig.new
			b = Jig.new(:"a/b")
			assert_equal(0, a[GAP].depth)
			assert_equal(1, b[:"a/b"].depth)
		end

		def test_escape
			ok = 'a'
			bad = '<'
			jok = Jig.new('a')
			jbad = Jig.new('<')
			assert_equal(jok, Jig.escape(ok))
			assert_same(jok, Jig.escape(jok))
			assert_not_equal(jbad.to_s, Jig.escape(bad).to_s)
			assert_equal('&lt;', Jig.escape(bad).to_s)
			assert_equal('&gt;', Jig.escape('>').to_s)
			assert_equal('&amp;', Jig.escape('&').to_s)
			assert_equal('&quot;', Jig.escape('"').to_s)
		end

		def test_freeze
			a = Jig.new
			assert(!a.frozen?)
			a.freeze
			assert(a.frozen?)
			assert_nothing_raised { a.plug 'a' }
			assert_raises(TypeError) { a << 'a' }
		end

		def old_test_dup_clone
			a = Jig.div
			b = a.dup
			assert_not_same(a, b)
			assert_similar(a, b)
			assert_equal(a, b)
			assert_not_similar(a, b.plug!("foo"))

			a = Jig.div
			b = a.deep_dup
			assert_not_same(a, b)
			assert_similar(a, b)
			assert_equal(a, b)
			assert_not_similar(a, b.plug!("foo"))

			b << "filled"
			assert_not_equal(a, b, 'deep duplicates are independent')
			assert_not_similar(a, b, 'deep duplicates are independent')
		end

		def test_conversion
			a = Jig.new('a', :alpha, 'b')
			assert_equal("axb", a.plug(:alpha, :beta).plug(:beta, 'x').to_s)
			b = ['gamma']
			class <<b; def to_jig() Jig.new(self.to_s[0,1]); end; end
			assert_equal("agb", a.plug(:alpha, :beta).plug(:beta, b).to_s)
		end

		def test_before
			j1 = Jig.new
			j2 = Jig.new(:alpha)
			assert_equal("xy", j1.before('x').plug('y').to_s)
			assert_equal("xy", j2.before(:alpha, 'x').plug(:alpha, 'y').to_s)
			assert_equal("yx", j1.after('x').plug('y').to_s)
			assert_equal("yx", j2.after(:alpha, 'x').plug(:alpha, 'y').to_s)
		end

		def test_wedge
			assert_equal("1X2X3", (Jig.new('X').wedge([1,2,3])).to_s)
		end

		def test_element_with_id
			j = Jig.element_with_id(:a, :href => "foo")
			assert_equal(%Q{<a href="foo" id="#{j.eid}"></a>\n}, j.to_s)
		end
	end
end

if __FILE__ == $0
	#Jig::Node.stats
end
