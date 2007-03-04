require 'jig'
require 'test/unit'

class Xjig < Jig
  enable :XML, :XHTML, :JavaScript
end

module XjigTest
	def assert_similar(a,b, mess="")
		assert_match(a, b, mess)
	end

	def assert_not_similar(a, b, mess="")
		assert_not_match(a, b, mess)
	end
end

class TestMeta < Test::Unit::TestCase
  def test_css
    css = Jig.derive :CSS
    assert(css < Jig, 'created subclass')
    assert(css.included_modules.include?(Jig::CSS), 'included correct modules')
    assert((class <<css; self; end).included_modules.include?(Jig::CSS::ClassMethods), 'included correct modules')
  end
end


class Xjig
	class TestXjig < Test::Unit::TestCase
		include XjigTest
		def test_creation
			# empty jigs and gaps
			assert_instance_of(Symbol, Jig::INNER)
			assert_instance_of(Xjig, Xjig.new)
			assert(!Xjig.new.closed?)
			assert((Xjig.new << 'full').closed?)

			# rendering of empty jigs and gaps
			assert_equal("", Xjig.new.to_s)
			assert_equal("", Xjig.new(:__gap).to_s)
			assert_equal("", Xjig.new(Jig::INNER).to_s)

			# testing ==
			assert_equal(Xjig.new(Jig::INNER).to_s, Xjig.new(Jig::INNER).to_s, 'equality via string conversion')
			assert_equal(Xjig.new(Jig::INNER), Xjig.new(Jig::INNER), 'equality via Xjig#==')

			# strings, no gaps
			assert_kind_of(Xjig, Xjig.new("a", "c"))
			assert_equal("ac", Xjig.new("a", "c").to_s)

			# gaps surrounding string
			assert_equal("string", Xjig.new("string").to_s)
			assert_equal("string", Xjig.new("string", Jig::INNER).to_s)
			assert_equal("string", Xjig.new(Jig::INNER, "string").to_s)
			assert_equal("string", Xjig.new(Jig::INNER, "string", Jig::INNER).to_s)

			# strings surrounding gaps
			assert_kind_of(Xjig, Xjig.new("a", Jig::INNER, "c"))
			assert_kind_of(String, Xjig.new("a", Jig::INNER, "c").to_s)
			assert_equal("ac", Xjig.new("a", Jig::INNER, "c").to_s)

			# gap invariance
			assert_similar(Xjig.new(:alpha, "a", :beta), Xjig.new(:beta, "a", :alpha), "gap name invariance")
			assert_not_equal(Xjig.new(:alpha, "a", :beta), Xjig.new(:beta, "a", :alpha), "gap name invariance")
			assert_similar(Xjig.new(:alpha, :beta, "a"), Xjig.new(:beta, "a"), "gap repetition invariance")
			assert_not_equal(Xjig.new(:alpha, :beta, "a"), Xjig.new(:beta, "a"), "gap repetition invariance")

			# multiple gaps
			assert_equal("ABC", Xjig.new(:alpha, :beta, :gamma).plug(:alpha, "A").plug(:beta, "B").plug(:gamma, "C").to_s, "three gaps")

			# creation with lambdas
			assert_equal("abc", Xjig.new( lambda { "abc" }).to_s)
			assert_not_equal(Xjig.new( lambda { "abc" }), Xjig.new( lambda { "abc" }))
			assert_match(Xjig.new( lambda { "abc" }), Xjig.new( lambda { "abc" }))
			abc = lambda { "abc" }
			assert_equal(Xjig.new(abc), Xjig.new(abc))
			assert_match(Xjig.new(abc), Xjig.new(abc))
			assert_equal("abc", Xjig.new(:alpha, lambda { "abc" }).to_s)
			assert_equal("123abc", Xjig.new("123", :alpha, lambda { "abc" }).to_s)
			assert_equal("wow", Xjig.new { "wow" }.to_s, 'lambda as block to new')
			assert_equal("argblock", Xjig.new("arg") { "block" }.to_s, 'args and lambda as block to new')
			assert_equal("arg1arg2block", Xjig.new("arg1", "arg2") { "block" }.to_s, 'args and lambda as block to new')

			# creation with arrays
			assert_equal(%Q{abc}, Xjig.new(["a", "b", "c"]).to_s)
			assert_equal(%Q{abc}, Xjig.new("a", ["b"], "c").to_s)

			# Hash is OK
			assert_nothing_raised(ArgumentError) {Xjig.new('a' => 'b')}
			assert_nothing_raised(ArgumentError) {Xjig.new("a", 'c'=>'d')}

			# Hash checks
			assert_equal(%Q{ a="b"}, Xjig.new('a' => 'b').to_s, 'create from Hash')
			assert_equal(%Q{ a="b" c="d"}, Xjig.new('a' => 'b', 'c' => 'd').to_s, 'create from Hash, 2 items')
			assert_equal(%Q{ a="b"}, Xjig.new(Jig::INNER, 'a' => 'b').to_s, 'hash and gap')
			assert_equal("", Xjig.new('a' => Jig::INNER).to_s, 'attribute suppression')

			assert_nothing_raised(ArgumentError, 'hash OK with #new') { Xjig.new(:div, "first", {'a' => 'b'}, "third") }
			assert_equal(%Q{first a="b"third}, Xjig.new(:div, "first", {'a' => 'b'}, "third").to_s)
		end

		def setup
			@a1c = Xjig.new("a", :alpha, "c")
			@d2f = Xjig.new("d", :beta, "f")
			@a1c2e = Xjig.new("a", :alpha, "c", :beta, "e")
		end

		def test_comparisons
			assert_equal("abc", Xjig["abc"].to_s)
			assert_match(Xjig["abc"], Xjig["a","b", "c"])
			assert_not_equal(Xjig["abc"], Xjig["a",:g1, "b", :g2, "c"])
			assert_match(Xjig["abc"], Xjig["a",:g1, "b", :g2, "c"])
		end

		def test_plugging
			# plugging gaps
			assert_equal("ac", Xjig.new("a", "c").plug("b").to_s)
			assert_kind_of(Xjig, Xjig.new("a", Jig::INNER, "c").plug("b"))
			assert_kind_of(String, Xjig.new("a", Jig::INNER, "c").plug("b").to_s)
			assert_equal("abc", Xjig.new("a", Jig::INNER, "c").plug("b").to_s)
			assert_equal("XaX", Xjig.new(Jig::INNER, "a", Jig::INNER).plug("X").to_s)

			# using << instead of #plug
			assert_equal("ac", (Xjig.new("a", "c") << ("b")).to_s)
			assert_kind_of(Xjig, Xjig.new("a", Jig::INNER, "c") << ("b"))
			assert_kind_of(String, (Xjig.new("a", Jig::INNER, "c")<<("b")).to_s)
			assert_equal("abc", (Xjig.new("a", Jig::INNER, "c")<<("b")).to_s)
			assert_equal("XaX", (Xjig.new(Jig::INNER, "a", Jig::INNER)<<("X")).to_s)

			# named gaps
			assert_equal(Xjig.new(:alpha).to_s, Xjig.new(:beta).to_s)
			assert_equal(Xjig.new("a", :alpha).to_s, Xjig.new("a", :beta).to_s)
			assert_equal(Xjig.new("a", :alpha).to_s, Xjig.new(:beta, "a").to_s)

			# plugging named gaps
			assert_similar(@a1c, Xjig.new("a", :alpha, :beta).plug(:beta, "c"))
			assert_equal("a", (Xjig.new("a", :alpha, :beta) << [:beta, "c"]).to_s)
			assert_similar(@a1c, (Xjig.new("a", :alpha, :beta) << [:beta, "c"] << {:beta, "c"} ))
			assert_equal("abc", (Xjig.new("a", :alpha, :beta) << [:beta, "c"] << {:beta, "c"}  << {:alpha, "b"} ).to_s)
			assert_equal("a", (Xjig.new("a", :alpha, :beta) << { Jig::INNER, "c"}).to_s)

			# plugging hashs
			assert_equal(%Q{ a="b"}, Xjig.new('a' => :alpha).plug(:alpha, "b").to_s, 'plugging an attribute')
			assert_equal(%Q{ a="b"}, Xjig.new('a' => :alpha).plug(:alpha, lambda { "b" }).to_s, 'plugging an attribute with a proc')
			assert_equal(%Q{}, Xjig.new('a' => :alpha).plug(:alpha, lambda { nil }).to_s, 'plugging an attribute with a proc returning nil')
			assert_equal(%Q{}, Xjig.new({'a',Jig::INNER}).plug(lambda { nil }).to_s, 'plugging an attribute with a proc returning nil')

			# plugging  gaps with other jigs
			assert_equal(%Q{abc}, Xjig.new("a", Jig::INNER, "c").plug(Xjig.new("b")).to_s, 'pluging gap with string Xjig')
			assert_equal(%Q{ac}, Xjig.new("a", :alpha, "c").plug(Xjig.new("b")).to_s, 'pluging non-existant gap')
			assert_not_equal(%Q{abc}, Xjig.new("a", :alpha, "c").plug(Xjig.new("b")).to_s, 'pluging non-existant gap')
			assert_equal(%Q{ac}, Xjig.new("a", :alpha, "c").plug(Xjig.new(:beta)).to_s, 'pluging gap with a gap')
			assert_not_equal(%Q{abc}, Xjig.new("a", :alpha, "c").plug(Xjig.new(:beta)).plug("b").to_s, 'pluging gap with a gap')
			assert_equal(%Q{ac}, Xjig.new("a", :alpha, "c").plug(:alpha, Xjig.new(:beta)).to_s, 'pluging gap with a gap')
			assert_not_equal(%Q{abc}, Xjig.new("a", :alpha, "c").plug(:alpha, Xjig.new(:beta)).to_s, 'pluging gap with a gap')
			assert_equal(%Q{b}, Xjig.new(:beta).plug(:beta, "b").to_s, '')
			assert_equal(%Q{}, Xjig.new(:beta).plug(:alpha, "b").to_s, '')
			assert_equal(%Q{b}, Xjig.new(:beta).plug(:beta, Xjig[:alpha, "b"]).to_s )
			assert_equal(%Q{abc}, Xjig.new("a", :alpha, "c").plug(:alpha, Xjig.new(:beta)).plug(:beta, "b").to_s, 'pluging gap with a gap')

			# implicit plugs
			assert_equal(%Q{abc}, (Xjig.new("a", Jig::INNER, "c") << Xjig.new(Jig::INNER) << "b").to_s, 'implicit names: plugging gap with a gap')
			assert_equal(%Q{abc}, (Xjig.new("a", Jig::INNER, "c") << Xjig.new(Jig::INNER) << "b").to_s, 'implicit names: plugging gap with a gap')
			assert_equal(%Q{abc}, (Xjig.new("a", Jig::INNER, "c") << Xjig.new << "b").to_s, 'implicit names: plugging gap with a gap')
		end

		def test_array
			assert_equal([], (Xjig.new << []).gap_list)
			assert_equal(%Q{}, (Xjig.new << []).to_s)
			assert_equal(%Q{ab}, (Xjig.new << ["a", "b"]).to_s)
			assert_equal(%Q{ab}, (Xjig.new << [["a", "b"]]).to_s)
			assert_equal(%Q{ab}, (Xjig.new << { Jig::INNER => ["a", "b"]}).to_s)
			assert_equal(%Q{}, (Xjig.new << {:alpha, ["b"]}).to_s)
			assert_equal(%Q{}, (Xjig.new << { :alpha => "b" }).to_s)
			assert_equal(%Q{b}, (Xjig.new << { Jig::INNER => Xjig[:alpha, "b"] }).to_s)
			assert_equal(%Q{ab}, (Xjig.new << { Jig::INNER => Xjig[:alpha, "b"] } << { :alpha => "a" } ).to_s)
			#assert_equal(%Q{cb}, (Xjig.new << Xjig[:alpha, "b"] << {:alpha, "c"}).to_s)
			assert_equal(%Q{cb}, (Xjig.new << Xjig[:alpha, "b"] << {:alpha => "c"}).to_s)
			assert_equal(%Q{cb}, ((Xjig.new << Xjig[:alpha, "b"]).plug(:alpha,"c")).to_s)
			assert_equal(%Q{b}, (Xjig.new(:alpha) << {:alpha, "b"} << {:alpha, "c"}).to_s)
			assert_equal(%Q{cb}, (Xjig.new << Xjig.new(:alpha, "b") << {:alpha, "c"}).to_s)
			assert_equal(%Q{cb}, (Xjig.new.plug(Jig::INNER, Xjig[:alpha, "b"]) << {:alpha, "c"}).to_s)
		end

		def test_element
			# element construction
			@div = "<div>\n</div>\n"
			assert_equal(@div, Xjig.element.to_s, 'default element as "div"')

			assert_equal(@div, Xjig.element(:div).to_s)
			assert_equal(@div, Xjig.element(:div, Jig::INNER).to_s)
			assert_equal(@div, Xjig.element(:div, Jig::INNER).to_s)
			assert_equal(@div, Xjig.element(:div, Xjig.new).to_s)

			@div2 = "<div>\ninside</div>\n"
			assert_equal(@div2, Xjig.element(:div, "inside").to_s)
			assert_equal(@div2, Xjig.element(:div, "in", "side").to_s)

			# element with attributes
			@div_empty = "<div>\n</div>\n"
			@div_1attr= %Q{<div a="b">\n</div>\n}
			@div_1attrfilled= %Q{<div a="b">\ninside</div>\n}
			@div_1attrfilled2= %Q{<div a="b">\ninsidealso</div>\n}
			assert_not_equal(@div_empty, Xjig.element(:div, 'a' => 'b').to_s)
			assert_equal(@div_1attr, Xjig.element(:div, 'a' => 'b').to_s)
			assert_equal(@div_1attrfilled, Xjig.element(:div, 'inside', {'a' => 'b'}).to_s)
			assert_equal(@div_1attrfilled, Xjig.element(:div, {'a' => 'b'}) { "inside" }.to_s)
			assert_equal(@div_1attrfilled, Xjig.element(:div, lambda { "inside" }, {'a' => 'b'} ).to_s)
			assert_equal(@div_1attrfilled2, (Xjig.element(:div, lambda { "inside" }, {'a' => 'b'} ) { "also" }).to_s)

			#assert_raise(ArgumentError, 'hash only as first argument') { Xjig.element(:div, "first", {'a' => 'b'}, "third") }
		end

		def test_method_missing
			assert_equal(Xjig.div, Xjig.element(:div))
			assert_equal(Xjig.div(Jig::INNER), Xjig.element(:div, Jig::INNER))
			assert_equal(Xjig.div(Jig::INNER), Xjig.element(:div, Jig::INNER))
			assert_equal(Xjig.div(Xjig.new), Xjig.element(:div, Xjig.new))

			assert_equal(Xjig.div_, Xjig.div)

			@div2 = "<div>\ninside</div>\n"
			assert_equal(@div2, Xjig.element(:div, "inside").to_s)
			assert_equal(@div2, Xjig.element(:div, "in", "side").to_s)

			# element with block
			assert_equal(@div2, (Xjig.element(:div) {"inside"}).to_s)

			assert_equal(@div2, Xjig.div("inside").to_s)
			assert_equal(@div2, Xjig.div("in", "side").to_s)

			# div with attributes
			@div_empty = "<div>\n</div>\n"
			@div_1attr= %Q{<div a="b">\n</div>\n}
			@div_1attrfilled= %Q{<div a="b">\ninside</div>\n}
			@div_1attrfilled2= %Q{<div a="b">\ninsidealso</div>\n}
			assert_not_equal(@div_empty, Xjig.div( 'a' => 'b').to_s)
			assert_equal(@div_1attr, Xjig.div( 'a' => 'b').to_s)
			assert_equal(@div_1attrfilled, Xjig.div( "inside", {'a' => 'b'} ).to_s)
			assert_equal(@div_1attrfilled, Xjig.div( {'a' => 'b'}) { "inside" }.to_s)
			assert_equal(@div_1attrfilled, Xjig.div(lambda { "inside" }, {'a' => 'b'} ).to_s)
			assert_equal(@div_1attrfilled2, (Xjig.div(lambda { "inside" },  {'a' => 'b'}) { "also" }).to_s)
		end

		def test_more_plugging
			@div = "<div>\nabc</div>\n"
			@jdiv = Xjig.new("<div>\nabc</div>\n")
			assert_equal(@div, @jdiv.to_s)
			assert_match(@jdiv, Xjig.div << "abc")
			assert_match(@jdiv, Xjig.div("abc"))
			assert_match(@jdiv, Xjig.div { "abc" })

			@divp = "<div>\n<p>\n</p>\n</div>\n"
			@pdiv = "<p>\n<div>\n</div>\n</p>\n"
			@jdivp = Xjig.new("<div>\n<p>\n</p>\n</div>\n")
			@jpdiv = Xjig.new("<p>\n<div>\n</div>\n</p>\n")
			assert_equal(@divp, @jdivp.to_s)
			assert_equal(@pdiv, @jpdiv.to_s)
			assert_similar(@jdivp, (Xjig.div << Xjig.p))
			assert_similar(@jpdiv, Xjig.p << Xjig.div)

			@full = %Q{<div a="b">\ninside</div>\n}
			@full_jig = Xjig.new(%Q{<div a="b">\ninside</div>\n})
			assert_equal(@full, @full_jig.to_s)
			assert_match(@full_jig, Xjig.div('a' => 'b') { "inside" })
			assert_match(@full_jig, Xjig.div("inside", {'a' => 'b'}))
		end

		def test_eid
			@div = %r{<div id="[^"]*">\n</div>\n}
			@input = %r{<input id="\w*"/>}
			@jig_div_id = Xjig.div_with_id
			@jig_input = Xjig.input!
			assert_match(@div, @jig_div_id.to_s)
			assert_raise(RuntimeError,'eid reassignment') { @jig_div_id.eid = "foo" }
			assert_match(@input, Xjig.input.to_s)
			assert_not_equal(Xjig.li_with_id.to_s, Xjig.li_with_id.to_s)
		end

		def test_misc
			#assert_raise(ArgumentError, 'attribute must be string') { Xjig.div('a' => :gap) << Xjig.p }
			#assert_raise(ArgumentError) { ((Xjig.div('a' => Jig::INNER) << Xjig.p).to_s) }

			assert_equal( "ab", (Xjig.new(:alpha, :beta) << {:alpha => 'a', :beta => 'b'}).to_s)
			assert_equal( "<div>\n</div>\n", (Xjig.div).to_s)
			assert_not_equal( "ab", Xjig.div.plug("ab").to_s)
			assert_equal( "<div>\nab</div>\n", Xjig.div.plug("ab").to_s)

			#assert_equal( %Q{<div a="b">ab</div>\n}, Xjig.div("a" => "b").to_s)
			assert_equal( %Q{<div a="b">\nfoo</div>\n}, Xjig.div("a" => "b").plug("foo").to_s)

			# test plug nil
			# test plug with Hash
		end
	end

	class MoreXjig < Test::Unit::TestCase
		include XjigTest

		def test_001_identities
			# empty jigs and gaps
      assert_instance_of(Symbol, Jig::INNER,	'Jig::INNER constant')
			assert_instance_of(Xjig, Xjig.new,		'EMPTY constant')
			assert_similar(Xjig.new(Jig::INNER), (Xjig.new), 'manual construction of an empty jig')
			assert_equal(Xjig.new(Jig::INNER), Xjig.new, 								'manual construction of an empty jig')
			assert_not_same(Xjig.new(Jig::INNER), Xjig.new, 						'manual construction of an empty jig is unique')

			assert_instance_of(Xjig, Xjig.new,			'empty construction')
			assert_instance_of(Xjig, Xjig.null,				'blank construction')
			assert_similar(Xjig.new, Xjig.null,   'blank construction similar to BLANK' )
			#assert_not_equal(Xjig.new, Xjig.new)

			assert_equal(0, Xjig.null.gap_count,	'blank construction has no gaps')
			assert_equal(1, Xjig.new.gap_count,		'empty construction has a gap')
			assert_equal("", Xjig.null.to_s,			'blank shows as empty string')
			assert_equal("", Xjig.new.to_s,				'empty shows as empty string')

			assert_similar(Xjig.new(:alpha), Xjig.new,		"gap names don't affect string values")
			assert_not_equal(Xjig.new(:alpha), Xjig.new,						"gap names define equality")
		end

		def test_002_creation

			# strings, no gaps
			assert_kind_of(Xjig, Xjig.new("a", "c"))
			assert_equal("ac", Xjig.new("a", "c").to_s)

			# gaps surrounding string
			assert_equal("string", Xjig.new("string").to_s)
			assert_equal("string", Xjig.new("string", Jig::INNER).to_s)
			assert_equal("string", Xjig.new(Jig::INNER, "string").to_s)
			assert_equal("string", Xjig.new(Jig::INNER, "string", Jig::INNER).to_s)

			# strings surrounding gaps
			assert_kind_of(Xjig, Xjig.new("a", :gap, "c"))
			assert_kind_of(String, Xjig.new("a", :gap, "c").to_s)
			assert_equal("ac", Xjig.new("a", :gap, "c").to_s)

			# gap invariance
			assert_not_equal(Xjig.new(:alpha, "a", :beta), Xjig.new(:beta, "a", :alpha), "gap name affects equality")
			assert_not_equal(Xjig.new(:alpha, :beta, "a"), Xjig.new(:beta, "a"), "two gaps are not the same as one")
			assert_similar(Xjig.new(:alpha, :beta, "a"), Xjig.new(:beta, "a"), "gaps don't affect output")

		end

		def test_003_plugging

			assert_similar(Xjig.new("X"), Xjig.new(:gap).plug(:gap, "X"), 'jig with just a gap')
			assert_not_equal(Xjig.new("X"), Xjig.new(:gap1, :gap2).plug(:gap1, "X"), 'jig with just a gap')
			assert_similar(Xjig.new("X"), Xjig.new(:gap1, :gap2).plug(:gap1, "X"), 'jig with just a gap')
			assert_not_equal(Xjig.new("X"), Xjig.new(:gap1, :gap2).plug(:gap2, "X"), 'jig with just a gap')
			assert_similar(Xjig.new("X"), Xjig.new(:gap1, :gap2).plug(:gap2, "X"), 'jig with just a gap')
			assert_similar(Xjig.new("XY"), Xjig.new(:gap1, :gap2).plug(:gap1, "X").plug(:gap2, "Y"), 'jig with just a gap')
			assert_similar(Xjig.new("XY"), Xjig.new(:gap1, :gap2).plug(:gap1, "X").plug(:gap2, "Y"), 'jig with just a gap')

			# plugging gaps with strings
			#assert_raise(RuntimeError, 'no gap available') { Xjig.new("a", "c").plug(:gap, "b") }
			assert_nothing_raised(RuntimeError) { Xjig.new("a", "c").plug(:gap, "b") }
			assert_equal("(X)", Xjig.new("(", :gap, ")").plug(:gap, "X").to_s)
			assert_equal("X()", Xjig.new(:gap, "(", ")").plug(:gap, "X").to_s)
			assert_equal("()X", Xjig.new("(", ")", :gap).plug(:gap, "X").to_s)

			# method_missing
			assert_equal("Aa", Xjig.new("A", Jig::INNER, "a").to_s)
			assert_equal("AXa", Xjig.new("A", Jig::INNER, "a").plug(Jig::INNER, "X").to_s)
			#assert_equal(Xjig.new("A", Jig::INNER, "a"), Xjig.a)
			#assert_not_equal(Xjig.new("A", :gap, "a"), Xjig.a)


		end
		def test_004_jig_plugging

			@X = Xjig.new("X")
			assert_similar(Xjig.new("-X"), Xjig.new("-", :gap).plug(:gap, "X"))
			@X = Xjig.new("X", Jig::INNER, "x")
			assert_not_equal(	Xjig.new("-Xx"), 					Xjig.new("-", :gap).plug(:gap, @X), 'remaining gap')
			assert_not_equal(	Xjig.new("-X", :gap, "x"),	Xjig.new("-", :gap).plug(:gap, @X), 'Jig::INNER != :gap')
			assert_similar(    	Xjig.new("-","X", Jig::INNER, "x"), 	Xjig.new("-", :gap).plug(:gap, @X), 'Jig::INNER == Jig::INNER')

			assert_similar(	Xjig.new("abXx"), 					Xjig.new("a", "b", :gap).plug(:gap, @X), 'gap in the middle')
			assert_similar(	Xjig.new("aXxb"), 					Xjig.new("a", :gap, "b").plug(:gap, @X), 'gap in the middle')
			assert_similar(	Xjig.new("Xxab"), 					Xjig.new(:gap, "a", "b").plug(:gap, @X), 'gap at the end')

			# Plug at the end with one item fill
			@one = Xjig.new("X")
			assert_similar(	Xjig.new("abX"), 					Xjig.new("a", "b", :gap).plug(:gap, @one), 'gap in the middle')
			assert_similar(	Xjig.new("aXb"), 					Xjig.new("a", :gap, "b").plug(:gap, @one), 'gap in the middle')
			assert_similar(	Xjig.new("Xab"), 					Xjig.new(:gap, "a", "b").plug(:gap, @one), 'gap at the end')

			@onetwo = Xjig.new(:gap1, :gap2).plug(:gap1, "1").plug(:gap2, "2")
			assert_similar(	Xjig.new("12"), 	@onetwo, 'constructed node')
			assert_similar(	Xjig.new("ab12"), 					Xjig.new("a", "b", :gap).plug(:gap, @onetwo), 'gap at the end')
			assert_similar(	Xjig.new("a12b"), 					Xjig.new("a", :gap, "b").plug(:gap, @onetwo), 'gap in the middle')
			assert_similar(	Xjig.new("12ab"), 					Xjig.new(:gap, "a", "b").plug(:gap, @onetwo), 'gap at the beginning')
		end

		def setup
			@a1c = Xjig.new("a", :alpha, "c")
			@d2f = Xjig.new("d", :beta, "f")
			@a1c2e = Xjig.new("a", :alpha, "c", :beta, "e")
		end

		def test_plugging
			# plugging gaps
			assert_kind_of(Xjig, Xjig.new("a", Jig::INNER, "c").plug("b"))
			assert_kind_of(String, Xjig.new("a", Jig::INNER, "c").plug("b").to_s)
			assert_equal("abc", Xjig.new("a", Jig::INNER, "c").plug("b").to_s)
			assert_equal("XaX", Xjig.new(Jig::INNER, "a", Jig::INNER).plug("X").to_s)

			# using << instead of #plug
			assert_nothing_raised(RuntimeError) { Xjig.new("a", "c") << ("b") }
			assert_kind_of(Xjig, Xjig.new("a", Jig::INNER, "c") << ("b"))
			assert_kind_of(String, (Xjig.new("a", Jig::INNER, "c")<<("b")).to_s)
			assert_equal("abc", (Xjig.new("a", Jig::INNER, "c")<<("b")).to_s)
			assert_equal("XaX", (Xjig.new(Jig::INNER, "a", Jig::INNER)<<("X")).to_s)

			# named gaps
			assert_equal(Xjig.new(:alpha).to_s, Xjig.new(:beta).to_s)
			assert_equal(Xjig.new("a", :alpha).to_s, Xjig.new("a", :beta).to_s)
			assert_equal(Xjig.new("a", :alpha).to_s, Xjig.new(:beta, "a").to_s)

			# plugging named gaps
			assert_equal(@a1c, Xjig.new("a", :alpha, :beta).plug(:beta, "c"))
			assert_equal("ac", (Xjig.new("a", :alpha, :beta) << { :beta, "c"}).to_s)
			assert_equal("ac", (Xjig.new("a", :alpha, :beta) << { :alpha, "c"}).to_s)

			# plugging hashs
			assert_equal(%Q{ a="b"}, Xjig.new('a' => :a).plug(:a, "b").to_s, 'plugging an attribute')
			assert_equal(%Q{ a="b"}, Xjig.new('a' => :a).plug(:a, lambda { "b" }).to_s, 'plugging an attribute with a proc')
			assert_equal(%Q{}, Xjig.new('a' => :a).plug(:a, lambda { nil }).to_s, 'plugging an attribute with a proc returning nil')
			assert_equal(%Q{}, Xjig.new({'a',:a}).plug(lambda { nil }).to_s, 'plugging an attribute with a proc returning nil')

			# plugging  gaps with other jigs
			assert_equal(%Q{abc}, Xjig.new("a", Jig::INNER, "c").plug(Xjig.new("b")).to_s, 'pluging gap with string Xjig')
			assert_nothing_raised(RuntimeError, 'pluging non-existant gap') { Xjig.new("a", :alpha, "c").plug(Xjig.new("b")).to_s }
			assert_equal(%Q{ac}, Xjig.new("a", :alpha, "c").plug(:alpha, Xjig.new(:beta)).to_s, 'pluging gap with a gap')
			assert_not_equal(%Q{abc}, Xjig.new("a", :alpha, "c").plug(:alpha, Xjig.new(:beta)).to_s, 'pluging gap with a gap')
			assert_equal(%Q{b}, Xjig.new(:beta).plug(:beta, "b").to_s, '')
			assert_equal(%Q{abc}, Xjig.new("a", :alpha, "c").plug(:alpha, Xjig.new(:beta)).plug(:beta, "b").to_s, 'pluging gap with a gap')

			# implicit plugs
			assert_equal(%Q{abc}, (Xjig.new("a", Jig::INNER, "c") << Xjig.new(Jig::INNER) << "b").to_s, 'implicit names: plugging gap with a gap')
			assert_equal(%Q{abc}, (Xjig.new("a", Jig::INNER, "c") << Xjig.new(Jig::INNER) << "b").to_s, 'implicit names: plugging gap with a gap')
			assert_equal(%Q{abc}, (Xjig.new("a", Jig::INNER, "c") << Xjig.new << "b").to_s, 'implicit names: plugging gap with a gap')

		end
	end

	class MultipleGaps < Test::Unit::TestCase
		include XjigTest

		def test_001
			#assert_similar( Xjig.new("X-X"), Xjig.new(:gap, "-", :gap).plug(:gap, "X"))
			assert_similar( Xjig.new("-X-X-"), Xjig.new("-", :gap, "-", :gap, "-").plug(:gap, "X"))
		end

		def test_002
			assert_similar( Xjig.p, Xjig.p)
			assert_equal( Xjig.p, Xjig.p)
			#assert_same( Xjig.p, Xjig.p)
		end

		def test_003
			assert_similar(Xjig.new("abc"), Xjig.new("a") + Xjig.new("b") + Xjig.new("c"))
			assert_similar(Xjig.new("abc"), Xjig.new << Xjig[Xjig.new("a"), Xjig.new("b"), Xjig.new("c")])
			assert_similar(Xjig.new("abc"), Xjig.new << Xjig[Xjig.new("a"), Jig::INNER, Xjig.new("c")] << "b")
		end

		def test_addition
			assert_equal(Xjig.new(Xjig.div, Xjig.div), (Xjig.div + Xjig.div))
		end

		def test_misc
			#assert_raise(ArgumentError, 'attribute must be string') { Xjig.div('a' => :gap) << Xjig.p }
			#assert_raise(ArgumentError) { ((Xjig.div('a' => Jig::INNER) << Xjig.p).to_s) }

			assert_equal( "ab", (Xjig.new(:alpha, :beta) << {:alpha => 'a', :beta => 'b'}).to_s)
			assert_equal( "<div>\n</div>\n", (Xjig.div).to_s)
			assert_not_equal( "ab", Xjig.div.plug("ab").to_s)
			assert_equal( "<div>\nab</div>\n", Xjig.div.plug("ab").to_s)

			assert_equal( %Q{<div a="b">\n</div>\n}, Xjig.div("a" => "b").to_s)
			assert_equal( %Q{<div a="b">\nfoo</div>\n}, Xjig.div("a" => "b").plug("foo").to_s)
			assert_equal( %Q{<div a="foo">\n</div>\n}, Xjig.div("a" => :a).plug(:a, "foo").to_s)
			assert_equal( %Q{<div>\nbar</div>\n}, Xjig.div("a" => nil).plug("bar").to_s)
			assert_equal( %Q{<div a="">\nbar</div>\n}, Xjig.div("a" => "").plug("bar").to_s)
			assert_equal( %Q{<div a="foo">\nbar</div>\n}, Xjig.div("a" => :a).plug("bar").plug(:a, "foo").to_s)

			assert_equal( %Q{<div>\n</div>\n}, Xjig.div(nil).to_s)
		end

		def test_string_as_jig
			assert_equal("foo", Xjig.new("foo").to_s)
			assert_equal("XfooY", Xjig.new("X", :f, "Y").plug(:f, "foo").to_s)
			assert_equal("XfooY", Xjig.new("X", :f, "Y").plug({:f, "foo"}).to_s)
			assert_equal("XfooY", Xjig.new("X", :f, "Y").plug({:f, Xjig.new("foo")}).to_s)
			assert_equal("XfooY", Xjig.new("X", :f, :g, "Y").plug({:f, Xjig.new("foo")}).to_s)
			assert_equal("XXC", Xjig.new(:a, "X", :b, "X", :c).plug(:b, Xjig.new(:b1, :b2)).plug(:c, "C").to_s)
			assert_equal("Xfoo!gooY", Xjig.new("X", :f, "!", :g, "Y").plug(:f, Xjig.new("foo")).plug(:g, Xjig.new("goo")).to_s)
			assert_equal("Xfoo!gooY", Xjig.new("X", :f, "!", :g, "Y").plug({:f, Xjig.new("foo"), :g, Xjig.new("goo")}).to_s)
			assert_equal("XfoogooY", Xjig.new("X", :f, :g, "Y").plug({:f, Xjig.new("foo"), :g, Xjig.new("goo")}).to_s)
		end

		def test_1105
			assert_equal("xyzyx", (Xjig.new("x", Jig::INNER, "x") * [Xjig.new("y", Jig::INNER, "y")]).plug("z").to_s)
		end

		def test_attribute_with_gap
			j1 = Xjig.new("a", :gap1, "b")
			j2 = Xjig.form( :onsubmit => j1 )
			assert_equal("<form onsubmit=\"ab\">\n</form>\n", j2.to_s)
			assert_equal("<form onsubmit=\"ab\">\n</form>\n", j2.plug(:gap1, "X").to_s)
		end

		def xtest_depth
			a = Xjig.new
			b = Xjig.new(:"a/b")
			assert_equal(0, a[Jig::INNER].depth)
			assert_equal(1, b[:"a/b"].depth)
		end

		def test_escape
			ok = 'a'
			bad = '<'
			jok = Xjig.new('a')
			jbad = Xjig.new('<')
			assert_equal(jok, Xjig.escape(ok))
			assert_same(jok, Xjig.escape(jok))
			assert_not_equal(jbad.to_s, Xjig.escape(bad).to_s)
			assert_equal('&lt;', Xjig.escape(bad).to_s)
			assert_equal('&gt;', Xjig.escape('>').to_s)
			assert_equal('&amp;', Xjig.escape('&').to_s)
			assert_equal('&quot;', Xjig.escape('"').to_s)
		end

		def test_freeze
			a = Xjig.new
			assert(!a.frozen?)
			a.freeze
			assert(a.frozen?)
			assert_nothing_raised { a.plug 'a' }
			assert_raises(TypeError) { a << 'a' }
		end

		def old_test_dup_clone
			a = Xjig.div
			b = a.dup
			assert_not_same(a, b)
			assert_similar(a, b)
			assert_equal(a, b)
			assert_not_similar(a, b.plug!("foo"))

			a = Xjig.div
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
			a = Xjig.new('a', :alpha, 'b')
			assert_equal("axb", a.plug(:alpha, :beta).plug(:beta, 'x').to_s)
			b = ['gamma']
			class <<b; def to_jig() Xjig.new(self.to_s[0,1]); end; end
			assert_equal("agb", a.plug(:alpha, :beta).plug(:beta, b).to_s)
		end

		def test_before
			j1 = Xjig.new
			j2 = Xjig.new(:alpha)
			assert_equal("xy", j1.before('x').plug('y').to_s)
			assert_equal("xy", j2.before(:alpha, 'x').plug(:alpha, 'y').to_s)
			assert_equal("yx", j1.after('x').plug('y').to_s)
			assert_equal("yx", j2.after(:alpha, 'x').plug(:alpha, 'y').to_s)
		end

		def test_wedge
			assert_equal("1X2X3", (Xjig.new('X').wedge([1,2,3])).to_s)
		end

		def test_element_with_id
			j = Xjig.element_with_id(:a, :href => "foo")
      id, href = %Q{id="#{j.eid}"}, 'href="foo"'
			assert_match(%r{<a (#{id} #{href}|#{href} #{id})></a>\n}, j.to_s)
		end
	end
end
