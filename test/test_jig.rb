require 'jig'
require 'test/unit'
require 'test/jig'

class TestJig < Test::Unit::TestCase
  J = Jig
  include Asserts
  def test_creation
    # empty jigs and gaps
    assert_instance_of(Symbol, Jig::GAP)
    assert_instance_of(J, J.new)
    assert(!J.new.closed?)
    assert((J.new << 'full').closed?)

    # rendering of empty jigs and gaps
    assert_equal("", J.new.to_s)
    assert_equal("", J.new(:__gap).to_s)
    assert_equal("", J.new(Jig::GAP).to_s)

    # testing ==
    assert_equal(J.new(Jig::GAP).to_s, J.new(Jig::GAP).to_s, 'equality via string conversion')
    assert_equal(J.new(Jig::GAP), J.new(Jig::GAP), 'equality via X#==')

    # strings, no gaps
    assert_kind_of(J, J.new("a", "c"))
    assert_equal("ac", J.new("a", "c").to_s)

    # gaps surrounding string
    assert_equal("string", J.new("string").to_s)
    assert_equal("string", J.new("string", Jig::GAP).to_s)
    assert_equal("string", J.new(Jig::GAP, "string").to_s)
    assert_equal("string", J.new(Jig::GAP, "string", Jig::GAP).to_s)

    # strings surrounding gaps
    assert_kind_of(J, J.new("a", Jig::GAP, "c"))
    assert_kind_of(String, J.new("a", Jig::GAP, "c").to_s)
    assert_equal("ac", J.new("a", Jig::GAP, "c").to_s)

    # gap invariance
    assert_as_string(J.new(:alpha, "a", :beta), J.new(:beta, "a", :alpha), "gap name invariance")
    assert_not_equal(J.new(:alpha, "a", :beta), J.new(:beta, "a", :alpha), "gap name invariance")
    assert_as_string(J.new(:alpha, :beta, "a"), J.new(:beta, "a"), "gap repetition invariance")
    assert_not_equal(J.new(:alpha, :beta, "a"), J.new(:beta, "a"), "gap repetition invariance")

    # multiple gaps
    assert_equal("ABC", J.new(:alpha, :beta, :gamma).plug(:alpha, "A").plug(:beta, "B").plug(:gamma, "C").to_s, "three gaps")

    # creation with lambdas
    assert_equal("abc", J.new( lambda { "abc" }).to_s)
    assert_not_equal(J.new( lambda { "abc" }), J.new( lambda { "abc" }))
    assert_match(J.new( lambda { "abc" }), J.new( lambda { "abc" }))
    abc = lambda { "abc" }
    assert_equal(J.new(abc), J.new(abc))
    assert_match(J.new(abc), J.new(abc))
    assert_equal("abc", J.new(:alpha, lambda { "abc" }).to_s)
    assert_equal("123abc", J.new("123", :alpha, lambda { "abc" }).to_s)
    assert_equal("wow", J.new { "wow" }.to_s, 'lambda as block to new')
    assert_equal("argblock", J.new("arg") { "block" }.to_s, 'args and lambda as block to new')
    assert_equal("arg1arg2block", J.new("arg1", "arg2") { "block" }.to_s, 'args and lambda as block to new')

    # creation with lambdas that don't return strings
    assert_equal("42", J.new( lambda { 42 } ).to_s)
    assert_equal("42", (J.new { 42 }).to_s)

    # creation with arrays
    assert_equal(%Q{abc}, J.new(["a", "b", "c"]).to_s)
    assert_equal(%Q{abc}, J.new("a", ["b"], "c").to_s)

  end

  def setup
    @a1c = J.new("a", :alpha, "c")
    @d2f = J.new("d", :beta, "f")
    @a1c2e = J.new("a", :alpha, "c", :beta, "e")
  end

  def test_comparisons
    assert_equal("abc", J["abc"].to_s)
    assert_match(J["abc"], J["a","b", "c"])
    assert_not_equal(J["abc"], J["a",:g1, "b", :g2, "c"])
    assert_match(J["abc"], J["a",:g1, "b", :g2, "c"])
  end

  def test_plugging
    # plugging gaps
    assert_equal("ac", J.new("a", "c").plug("b").to_s)
    assert_kind_of(J, J.new("a", Jig::GAP, "c").plug("b"))
    assert_kind_of(String, J.new("a", Jig::GAP, "c").plug("b").to_s)
    assert_equal("abc", J.new("a", Jig::GAP, "c").plug("b").to_s)
    assert_equal("XaX", J.new(Jig::GAP, "a", Jig::GAP).plug("X").to_s)

    # using << instead of #plug
    assert_equal("ac", (J.new("a", "c") << ("b")).to_s)
    assert_kind_of(J, J.new("a", Jig::GAP, "c") << ("b"))
    assert_kind_of(String, (J.new("a", Jig::GAP, "c")<<("b")).to_s)
    assert_equal("abc", (J.new("a", Jig::GAP, "c")<<("b")).to_s)
    assert_equal("XaX", (J.new(Jig::GAP, "a", Jig::GAP)<<("X")).to_s)

    # named gaps
    assert_equal(J.new(:alpha).to_s, J.new(:beta).to_s)
    assert_equal(J.new("a", :alpha).to_s, J.new("a", :beta).to_s)
    assert_equal(J.new("a", :alpha).to_s, J.new(:beta, "a").to_s)

    # plugging named gaps
    assert_as_string(@a1c, J.new("a", :alpha, :beta).plug(:beta, "c"))
    assert_equal("a", (J.new("a", :alpha, :beta) << [:beta, "c"]).to_s)
    assert_as_string(@a1c, (J.new("a", :alpha, :beta) << [:beta, "c"] << {:beta => "c"} ))
    assert_equal("abc", (J.new("a", :alpha, :beta) << [:beta, "c"] << {:beta => "c"}  << {:alpha => "b"} ).to_s)
    assert_equal("a", (J.new("a", :alpha, :beta) << { Jig::GAP => "c"}).to_s)

    # plugging  gaps with other jigs
    assert_equal(%Q{abc}, J.new("a", Jig::GAP, "c").plug(J.new("b")).to_s, 'pluging gap with string X')
    assert_equal(%Q{ac}, J.new("a", :alpha, "c").plug(J.new("b")).to_s, 'pluging non-existant gap')
    assert_not_equal(%Q{abc}, J.new("a", :alpha, "c").plug(J.new("b")).to_s, 'pluging non-existant gap')
    assert_equal(%Q{ac}, J.new("a", :alpha, "c").plug(J.new(:beta)).to_s, 'pluging gap with a gap')
    assert_not_equal(%Q{abc}, J.new("a", :alpha, "c").plug(J.new(:beta)).plug("b").to_s, 'pluging gap with a gap')
    assert_equal(%Q{ac}, J.new("a", :alpha, "c").plug(:alpha, J.new(:beta)).to_s, 'pluging gap with a gap')
    assert_not_equal(%Q{abc}, J.new("a", :alpha, "c").plug(:alpha, J.new(:beta)).to_s, 'pluging gap with a gap')
    assert_equal(%Q{b}, J.new(:beta).plug(:beta, "b").to_s, '')
    assert_equal(%Q{}, J.new(:beta).plug(:alpha, "b").to_s, '')
    assert_equal(%Q{b}, J.new(:beta).plug(:beta, J[:alpha, "b"]).to_s )
    assert_equal(%Q{abc}, J.new("a", :alpha, "c").plug(:alpha, J.new(:beta)).plug(:beta, "b").to_s, 'pluging gap with a gap')

    # implicit plugs
    assert_equal(%Q{abc}, (J.new("a", Jig::GAP, "c") << J.new(Jig::GAP) << "b").to_s, 'implicit names: plugging gap with a gap')
    assert_equal(%Q{abc}, (J.new("a", Jig::GAP, "c") << J.new(Jig::GAP) << "b").to_s, 'implicit names: plugging gap with a gap')
    assert_equal(%Q{abc}, (J.new("a", Jig::GAP, "c") << J.new << "b").to_s, 'implicit names: plugging gap with a gap')
  end

  def test_array
    assert_equal([], (J.new << []).gaps)
    assert_equal(%Q{}, (J.new << []).to_s)
    assert_equal(%Q{ab}, (J.new << ["a", "b"]).to_s)
    assert_equal(%Q{ab}, (J.new << [["a", "b"]]).to_s)
    assert_equal(%Q{ab}, (J.new << { Jig::GAP => ["a", "b"]}).to_s)
    assert_equal(%Q{}, (J.new << {:alpha => ["b"]}).to_s)
    assert_equal(%Q{}, (J.new << { :alpha => "b" }).to_s)
    assert_equal(%Q{b}, (J.new << { Jig::GAP => J[:alpha, "b"] }).to_s)
    assert_equal(%Q{ab}, (J.new << { Jig::GAP => J[:alpha, "b"] } << { :alpha => "a" } ).to_s)
    assert_equal(%Q{cb}, (J.new << J[:alpha, "b"] << {:alpha => "c"}).to_s)
    assert_equal(%Q{cb}, ((J.new << J[:alpha, "b"]).plug(:alpha => "c")).to_s)
    assert_equal(%Q{b}, (J.new(:alpha) << {:alpha => "b"} << {:alpha => "c"}).to_s)
    assert_equal(%Q{cb}, (J.new << J.new(:alpha, "b") << {:alpha => "c"}).to_s)
    assert_equal(%Q{cb}, (J.new.plug(Jig::GAP, J[:alpha, "b"]) << {:alpha => "c"}).to_s)
  end

  def test_plug_block
    j = Jig.new(:alpha, :beta)
    h = {:alpha => 'a', :beta => 'b' }
    assert_equal("ab", j.plug {|g| h[g] }.to_s)
  end

  def test_plug_gap_sequence
    c = Jig.new.plug(:___, :title, :head, :foo)
    assert_equal([:title, :head, :foo], c.gaps)
    assert_equal(4, c.contents.size)
  end

  def test_plug_default_with_gap
    assert_equal([:alpha], Jig.new.plug(:alpha).gaps)
  end

	def test_plug_single_gap
    c = Jig.new.plug(:alpha)
    assert_equal([:alpha], c.gaps)
    assert_equal(2, c.contents.size)
	end

  def test_slice_position
    j = Jig.new(0, :alpha, 'z')
    assert_equal(Jig[0], j.slice(0))
    assert_equal(Jig[:alpha], j.slice(1))
    assert_equal(Jig['z'], j.slice(2))
  end

  def test_slice_range
    j = Jig.new(0, :alpha, 'z')
    assert_equal(Jig[0, :alpha],      j.slice(0..1))
    assert_equal(Jig[:alpha, 'z'],    j.slice(1..2))
  end
  def test_slice_start_length
    j = Jig.new(0, :alpha, 'z')
    assert_equal(Jig[0],              j.slice(0,1))
    assert_equal(Jig[0, :alpha],      j.slice(0,2))
    assert_equal(Jig[:alpha, 'z'],    j.slice(1,2))
    assert_equal(Jig[:alpha],         j.slice(1,1))
  end
  def test_slice_negative_index
    j = Jig.new(0, :alpha, 'z')
    assert_equal(Jig['z'],          j.slice(-1))
    assert_equal(Jig[:alpha, 'z'],  j.slice(-2..-1))
    assert_equal(Jig[:alpha],       j.slice(-2, 1))
  end

  def test_fill
    j = Jig.new(:alpha, :beta)
    j2 = j.plug { |g| g.to_s }
    assert_equal("alphabeta", j2.to_s)
  end

  def test_plugn
    list = Jig[:item, ',',  :item, ',', :item]
    assert_equal( ",second,", list.plugn(1, 'second').to_s)
    assert_equal( ",second,third", list.plugn(1..2, %w{second third}).to_s)
    assert_equal( "first,,", list.plugn('first').to_s)
    assert_equal( "first,second,", list.plugn(%w{first second}).to_s)
    assert_equal( "first,,third", list.plugn(0 => 'first', 2 => 'third').to_s)
  end

  def test_plug_nil
    assert_equal("", Jig.new.plug(:___ => nil).to_s)
  end
end


class MoreX < Test::Unit::TestCase
  include Asserts

  X = Jig::XHTML
  def test_001_identities
    # empty jigs and gaps
    assert_instance_of(Symbol, Jig::GAP,	'Jig::GAP constant')
    assert_instance_of(X, X.new,		'EMPTY constant')
    assert_as_string(X.new(Jig::GAP), (X.new), 'manual construction of an empty jig')
    assert_equal(X.new(Jig::GAP), X.new, 								'manual construction of an empty jig')
    assert_not_same(X.new(Jig::GAP), X.new, 						'manual construction of an empty jig is unique')

    assert_instance_of(X, X.new,			'empty construction')
    assert_instance_of(X, X.null,				'blank construction')
    assert_as_string(X.new, X.null,   'blank construction similar to BLANK' )
    #assert_not_equal(X.new, X.new)

    assert_equal(0, X.null.gaps.size,	'blank construction has no gaps')
    assert_equal(1, X.new.gaps.size,		'empty construction has a gap')
    assert_equal("", X.null.to_s,			'blank shows as empty string')
    assert_equal("", X.new.to_s,				'empty shows as empty string')

    assert_as_string(X.new(:alpha), X.new,		"gap names don't affect string values")
    assert_not_equal(X.new(:alpha), X.new,						"gap names define equality")
  end

  def test_002_creation

    # strings, no gaps
    assert_kind_of(X, X.new("a", "c"))
    assert_equal("ac", X.new("a", "c").to_s)

    # gaps surrounding string
    assert_equal("string", X.new("string").to_s)
    assert_equal("string", X.new("string", Jig::GAP).to_s)
    assert_equal("string", X.new(Jig::GAP, "string").to_s)
    assert_equal("string", X.new(Jig::GAP, "string", Jig::GAP).to_s)

    # strings surrounding gaps
    assert_kind_of(X, X.new("a", :gap, "c"))
    assert_kind_of(String, X.new("a", :gap, "c").to_s)
    assert_equal("ac", X.new("a", :gap, "c").to_s)

    # gap invariance
    assert_not_equal(X.new(:alpha, "a", :beta), X.new(:beta, "a", :alpha), "gap name affects equality")
    assert_not_equal(X.new(:alpha, :beta, "a"), X.new(:beta, "a"), "two gaps are not the same as one")
    assert_as_string(X.new(:alpha, :beta, "a"), X.new(:beta, "a"), "gaps don't affect output")

  end

  def test_003_plugging

    assert_as_string(X.new("X"), X.new(:gap).plug(:gap, "X"), 'jig with just a gap')
    assert_not_equal(X.new("X"), X.new(:gap1, :gap2).plug(:gap1, "X"), 'jig with just a gap')
    assert_as_string(X.new("X"), X.new(:gap1, :gap2).plug(:gap1, "X"), 'jig with just a gap')
    assert_not_equal(X.new("X"), X.new(:gap1, :gap2).plug(:gap2, "X"), 'jig with just a gap')
    assert_as_string(X.new("X"), X.new(:gap1, :gap2).plug(:gap2, "X"), 'jig with just a gap')
    assert_as_string(X.new("XY"), X.new(:gap1, :gap2).plug(:gap1, "X").plug(:gap2, "Y"), 'jig with just a gap')
    assert_as_string(X.new("XY"), X.new(:gap1, :gap2).plug(:gap1, "X").plug(:gap2, "Y"), 'jig with just a gap')

    # plugging gaps with strings
    #assert_raise(RuntimeError, 'no gap available') { X.new("a", "c").plug(:gap, "b") }
    assert_nothing_raised(RuntimeError) { X.new("a", "c").plug(:gap, "b") }
    assert_equal("(X)", X.new("(", :gap, ")").plug(:gap, "X").to_s)
    assert_equal("X()", X.new(:gap, "(", ")").plug(:gap, "X").to_s)
    assert_equal("()X", X.new("(", ")", :gap).plug(:gap, "X").to_s)

    # method_missing
    assert_equal("Aa", X.new("A", Jig::GAP, "a").to_s)
    assert_equal("AXa", X.new("A", Jig::GAP, "a").plug(Jig::GAP, "X").to_s)
    #assert_equal(X.new("A", Jig::GAP, "a"), X.a)
    #assert_not_equal(X.new("A", :gap, "a"), X.a)


  end
  def test_004_jig_plugging

    @X = X.new("X")
    assert_as_string(X.new("-X"), X.new("-", :gap).plug(:gap, "X"))
    @X = X.new("X", Jig::GAP, "x")
    assert_not_equal(	X.new("-Xx"), 					X.new("-", :gap).plug(:gap, @X), 'remaining gap')
    assert_not_equal(	X.new("-X", :gap, "x"),	X.new("-", :gap).plug(:gap, @X), 'Jig::GAP != :gap')
    assert_as_string(    	X.new("-","X", Jig::GAP, "x"), 	X.new("-", :gap).plug(:gap, @X), 'Jig::GAP == Jig::GAP')

    assert_as_string(	X.new("abXx"), 					X.new("a", "b", :gap).plug(:gap, @X), 'gap in the middle')
    assert_as_string(	X.new("aXxb"), 					X.new("a", :gap, "b").plug(:gap, @X), 'gap in the middle')
    assert_as_string(	X.new("Xxab"), 					X.new(:gap, "a", "b").plug(:gap, @X), 'gap at the end')

    # Plug at the end with one item fill
    @one = X.new("X")
    assert_as_string(	X.new("abX"), 					X.new("a", "b", :gap).plug(:gap, @one), 'gap in the middle')
    assert_as_string(	X.new("aXb"), 					X.new("a", :gap, "b").plug(:gap, @one), 'gap in the middle')
    assert_as_string(	X.new("Xab"), 					X.new(:gap, "a", "b").plug(:gap, @one), 'gap at the end')

    @onetwo = X.new(:gap1, :gap2).plug(:gap1, "1").plug(:gap2, "2")
    assert_as_string(	X.new("12"), 	@onetwo, 'constructed node')
    assert_as_string(	X.new("ab12"), 					X.new("a", "b", :gap).plug(:gap, @onetwo), 'gap at the end')
    assert_as_string(	X.new("a12b"), 					X.new("a", :gap, "b").plug(:gap, @onetwo), 'gap in the middle')
    assert_as_string(	X.new("12ab"), 					X.new(:gap, "a", "b").plug(:gap, @onetwo), 'gap at the beginning')
  end

  def setup
    @a1c = X.new("a", :alpha, "c")
    @d2f = X.new("d", :beta, "f")
    @a1c2e = X.new("a", :alpha, "c", :beta, "e")
  end

  def test_plugging
    # plugging gaps
    assert_kind_of(X, X.new("a", Jig::GAP, "c").plug("b"))
    assert_kind_of(String, X.new("a", Jig::GAP, "c").plug("b").to_s)
    assert_equal("abc", X.new("a", Jig::GAP, "c").plug("b").to_s)
    assert_equal("XaX", X.new(Jig::GAP, "a", Jig::GAP).plug("X").to_s)

    # using << instead of #plug
    assert_nothing_raised(RuntimeError) { X.new("a", "c") << ("b") }
    assert_kind_of(X, X.new("a", Jig::GAP, "c") << ("b"))
    assert_kind_of(String, (X.new("a", Jig::GAP, "c")<<("b")).to_s)
    assert_equal("abc", (X.new("a", Jig::GAP, "c")<<("b")).to_s)
    assert_equal("XaX", (X.new(Jig::GAP, "a", Jig::GAP)<<("X")).to_s)

    # named gaps
    assert_equal(X.new(:alpha).to_s, X.new(:beta).to_s)
    assert_equal(X.new("a", :alpha).to_s, X.new("a", :beta).to_s)
    assert_equal(X.new("a", :alpha).to_s, X.new(:beta, "a").to_s)

    # plugging named gaps
    assert_equal(@a1c, X.new("a", :alpha, :beta).plug(:beta, "c"))
    assert_equal("ac", (X.new("a", :alpha, :beta) << { :beta => "c"}).to_s)
    assert_equal("ac", (X.new("a", :alpha, :beta) << { :alpha => "c"}).to_s)

    # plugging hashs
    assert_equal(%Q{ a="b"}, X.new('a' => :a).plug(:a, "b").to_s, 'plugging an attribute')
    assert_equal(%Q{ a="b"}, X.new('a' => :a).plug(:a, lambda { "b" }).to_s, 'plugging an attribute with a proc')
    assert_equal(%Q{}, X.new('a' => :a).plug(:a, lambda { nil }).to_s, 'plugging an attribute with a proc returning nil')
    assert_equal(%Q{}, X.new({'a' => :a}).plug(lambda { nil }).to_s, 'plugging an attribute with a proc returning nil')

    # plugging  gaps with other jigs
    assert_equal(%Q{abc}, X.new("a", Jig::GAP, "c").plug(X.new("b")).to_s, 'pluging gap with string X')
    assert_nothing_raised(RuntimeError, 'pluging non-existant gap') { X.new("a", :alpha, "c").plug(X.new("b")).to_s }
    assert_equal(%Q{ac}, X.new("a", :alpha, "c").plug(:alpha, X.new(:beta)).to_s, 'pluging gap with a gap')
    assert_not_equal(%Q{abc}, X.new("a", :alpha, "c").plug(:alpha, X.new(:beta)).to_s, 'pluging gap with a gap')
    assert_equal(%Q{b}, X.new(:beta).plug(:beta, "b").to_s, '')
    assert_equal(%Q{abc}, X.new("a", :alpha, "c").plug(:alpha, X.new(:beta)).plug(:beta, "b").to_s, 'pluging gap with a gap')

    # implicit plugs
    assert_equal(%Q{abc}, (X.new("a", Jig::GAP, "c") << X.new(Jig::GAP) << "b").to_s, 'implicit names: plugging gap with a gap')
    assert_equal(%Q{abc}, (X.new("a", Jig::GAP, "c") << X.new(Jig::GAP) << "b").to_s, 'implicit names: plugging gap with a gap')
    assert_equal(%Q{abc}, (X.new("a", Jig::GAP, "c") << X.new << "b").to_s, 'implicit names: plugging gap with a gap')

  end
end

class MultipleGaps < Test::Unit::TestCase
  include Asserts
  X = Jig::XHTML
  def test_001
    #assert_as_string( X.new("X-X"), X.new(:gap, "-", :gap).plug(:gap, "X"))
    assert_as_string( X.new("-X-X-"), X.new("-", :gap, "-", :gap, "-").plug(:gap, "X"))
  end

  def test_002
    assert_as_string( X.p, X.p)
    assert_equal( X.p, X.p)
    #assert_same( X.p, X.p)
  end

  def test_003
    assert_as_string(X.new("abc"), X.new("a") + X.new("b") + X.new("c"))
    assert_as_string(X.new("abc"), X.new << X[X.new("a"), X.new("b"), X.new("c")])
    assert_as_string(X.new("abc"), X.new << X[X.new("a"), Jig::GAP, X.new("c")] << "b")
  end

  def test_addition
    assert_equal(X.new(X.div, X.div), (X.div + X.div))
  end

  def test_misc
    #assert_raise(ArgumentError, 'attribute must be string') { X.div('a' => :gap) << X.p }
    #assert_raise(ArgumentError) { ((X.div('a' => Jig::GAP) << X.p).to_s) }

    assert_equal( "ab", (X.new(:alpha, :beta) << {:alpha => 'a', :beta => 'b'}).to_s)
    assert_equal( "<div>\n</div>\n", (X.div).to_s)
    assert_not_equal( "ab", X.div.plug("ab").to_s)
    assert_equal( "<div>\nab</div>\n", X.div.plug("ab").to_s)

    assert_equal( %Q{<div a="b">\n</div>\n}, X.div("a" => "b").to_s)
    assert_equal( %Q{<div a="b">\nfoo</div>\n}, X.div("a" => "b").plug("foo").to_s)
    assert_equal( %Q{<div a="foo">\n</div>\n}, X.div("a" => :a).plug(:a, "foo").to_s)
    assert_equal( %Q{<div>\nbar</div>\n}, X.div("a" => nil).plug("bar").to_s)
    assert_equal( %Q{<div a="">\nbar</div>\n}, X.div("a" => "").plug("bar").to_s)
    assert_equal( %Q{<div a="foo">\nbar</div>\n}, X.div("a" => :a).plug("bar").plug(:a, "foo").to_s)

    assert_equal( %Q{<div>\n</div>\n}, X.div(nil).to_s)
  end

  def test_string_as_jig
    assert_equal("foo", X.new("foo").to_s)
    assert_equal("XfooY", X.new("X", :f, "Y").plug(:f, "foo").to_s)
    assert_equal("XfooY", X.new("X", :f, "Y").plug({:f =>"foo"}).to_s)
    assert_equal("XfooY", X.new("X", :f, "Y").plug({:f =>X.new("foo")}).to_s)
    assert_equal("XfooY", X.new("X", :f, :g, "Y").plug({:f =>X.new("foo")}).to_s)
    assert_equal("XXC", X.new(:a, "X", :b, "X", :c).plug(:b, X.new(:b1, :b2)).plug(:c, "C").to_s)
    assert_equal("Xfoo!gooY", X.new("X", :f, "!", :g, "Y").plug(:f, X.new("foo")).plug(:g, X.new("goo")).to_s)
    assert_equal("Xfoo!gooY", X.new("X", :f, "!", :g, "Y").plug({:f => X.new("foo"), :g => X.new("goo")}).to_s)
    assert_equal("XfoogooY", X.new("X", :f, :g, "Y").plug({:f => X.new("foo"), :g => X.new("goo")}).to_s)
  end

  def test_1105
    assert_equal("xyzyx", (X.new("x", Jig::GAP, "x") * [X.new("y", Jig::GAP, "y")]).plug("z").to_s)
  end

  def test_attribute_with_gap
    j1 = X.new("a", :gap1, "b")
    j2 = X.form( :onsubmit => j1 )
    assert_equal("<form onsubmit=\"ab\">\n</form>\n", j2.to_s)
    assert_equal("<form onsubmit=\"ab\">\n</form>\n", j2.plug(:gap1, "X").to_s)
  end

  def test_escape
    ok = 'a'
    bad = '<'
    jok = X.new('a')
    jbad = X.new('<')
    assert_equal(jok, X.escape(ok))
    assert_equal(jok, X.escape(jok))
    assert_not_same(jok, X.escape(jok))
    assert_not_equal(jbad.to_s, X.escape(bad).to_s)
    assert_equal('&lt;', X.escape(bad).to_s)
    assert_equal('&gt;', X.escape('>').to_s)
    assert_equal('&amp;', X.escape('&').to_s)
    assert_equal('&quot;', X.escape('"').to_s)
  end

  def test_freeze
    a = X.new
    assert(!a.frozen?)
    a.freeze
    assert(a.frozen?)
    assert_nothing_raised { a.plug 'a' }
    assert_raises(TypeError) { a << 'a' }
  end

  def test_conversion
    a = X.new('a', :alpha, 'b')
    assert_equal("axb", a.plug(:alpha, :beta).plug(:beta, 'x').to_s)
    b = Object.new
    class <<b; def to_jig() X.new('g'); end; end
    assert_equal("agb", a.plug(:alpha, :beta).plug(:beta, b).to_s)
  end

  def test_before
    j1 = X.new
    j2 = X.new(:alpha)
    assert_equal("xy", j1.before('x').plug('y').to_s)
    assert_equal("xy", j2.before(:alpha, 'x').plug(:alpha, 'y').to_s)
    assert_equal("yx", j1.after('x').plug('y').to_s)
    assert_equal("yx", j2.after(:alpha, 'x').plug(:alpha, 'y').to_s)
  end

  def test_plug_from_hash
    j = Jig.new(:alpha, :beta)
    h = {:alpha => 'a', :beta => 'b' }
    h2 = {:alpha => :beta, :beta => 'b' }
    assert_equal("ab", j.plug(h).to_s)
    result2 = j.plug(h2)
    assert_equal("b", result2.to_s)
    assert_equal([:beta], result2.gaps)
  end

	def test_distribute_to_gaps
		j = Jig.new * [:alpha, :beta]
		assert_equal [:alpha, :beta], j.gaps
		assert_equal "ab", j.plug(:alpha => 'a', :beta => 'b').to_s
	end

  def test_plug_all_gaps
    j = Jig.new(:a, :b, :___)
    assert_equal [], j.plug.gaps
  end

  def test_wrap
    ten = Jig.new(Jig::Gap.wrap(10))
    assert_equal "this is ok", ten.plug("this is ok").to_s
    assert_equal "this will\nbe split", ten.plug("this will be split").to_s
  end

  def test_comment
    ten = Jig.new(Jig::Gap.comment(nil, nil, nil, 10))
    assert_equal "this is ok\n", ten.plug("this is ok\n").to_s
    assert_equal "this will\nbe split\n", ten.plug("this will be split\n").to_s
    #   Jig::Gap.comment                    # text reformated to 72 columns
    #   Jig::Gap.comment(:___, "# ")        # text reformated as Ruby comments
    #   Jig::Gap.comment(:___, "// ")       # text reformated as Javascript comments
    #   Jig::Gap.comment(:___, " *", "/* ") # text reformated as C comments
    #   Jig::Gap.comment(:___, " ", "<-- ", " -->") # text reformated as XML comments
  end
end
