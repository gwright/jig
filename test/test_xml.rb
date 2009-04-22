require 'jig'
require 'test/unit'
require 'test/jig'

class TestXML < Test::Unit::TestCase
  X = Jig::XML
  A = Class.new(X)
  include Asserts
  def setup
    @div = X.element('div')
    @gaps = [:___]
  end

  def test_comment
    assert_as_string("<!--  -->\n", X.comment)
    assert_equal(@gaps, X.comment.gaps)
    assert_as_string("<!-- comment -->\n", X.comment('comment'))
  end

  def test_xml
    assert_as_string(%Q{<?xml version="1.0" ?>\n}, X.xml)
    v,e = %Q{version="1.0"}, %Q{encoding="UTF-8"}
    assert_as_string(/<\?xml (#{e} #{v}|#{v} #{e}) \?>\n/, X.xml(:encoding => "UTF-8"))
  end

  def test_hash
    # Hash is OK
    assert_nothing_raised(ArgumentError) {X.new('a' => 'b')}
    assert_nothing_raised(ArgumentError) {X.new("a", 'c'=>'d')}

    # Hash checks
    assert_equal(%Q{ a="b"}, X.new('a' => 'b').to_s, 'create from Hash')
    assert_equal(%Q{ a="b" c="d"}, X.new('a' => 'b', 'c' => 'd').to_s, 'create from Hash, 2 items')
    assert_equal(%Q{ a="b"}, X.new(Jig::GAP, 'a' => 'b').to_s, 'hash and gap')
    assert_equal("", X.new('a' => Jig::GAP).to_s, 'attribute suppression')

    assert_nothing_raised(ArgumentError, 'hash OK with #new') { X.new(:div, "first", {'a' => 'b'}, "third") }
    assert_equal(%Q{first a="b"third}, X.new(:div, "first", {'a' => 'b'}, "third").to_s)
  end

  def test_plug_hash
    # plugging hashs
    assert_equal(%Q{ a="b"}, X.new('a' => :alpha).plug(:alpha, "b").to_s, 'plugging an attribute')
    assert_equal(%Q{ a="b"}, X.new('a' => :alpha).plug(:alpha, lambda { "b" }).to_s, 'plugging an attribute with a proc')
    assert_equal(%Q{}, X.new('a' => :alpha).plug(:alpha, lambda { nil }).to_s, 'plugging an attribute with a proc returning nil')
    assert_equal(%Q{}, X.new({'a' => Jig::GAP}).plug(lambda { nil }).to_s, 'plugging an attribute with a proc returning nil')
  end

  def test_element
    # element construction
    @div = "<div>\n</div>\n"
    assert_equal(@div, X.element.to_s, 'default element as "div"')

    assert_equal(@div, X.element(:div).to_s)
    assert_equal(@div, X.element(:div, Jig::GAP).to_s)
    assert_equal(@div, X.element(:div, Jig::GAP).to_s)
    assert_equal(@div, X.element(:div, X.new).to_s)

    @div2 = "<div>\ninside</div>\n"
    assert_equal(@div2, X.element(:div, "inside").to_s)
    assert_equal(@div2, X.element(:div, "in", "side").to_s)

    # element with attributes
    @div_empty = "<div>\n</div>\n"
    @div_1attr= %Q{<div a="b">\n</div>\n}
    @div_1attrfilled= %Q{<div a="b">\ninside</div>\n}
    @div_1attrfilled2= %Q{<div a="b">\ninsidealso</div>\n}
    assert_not_equal(@div_empty, X.element(:div, 'a' => 'b').to_s)
    assert_equal(@div_1attr, X.element(:div, 'a' => 'b').to_s)
    assert_equal(@div_1attrfilled, X.element(:div, 'inside', {'a' => 'b'}).to_s)
    assert_equal(@div_1attrfilled, X.element(:div, {'a' => 'b'}) { "inside" }.to_s)
    assert_equal(@div_1attrfilled, X.element(:div, lambda { "inside" }, {'a' => 'b'} ).to_s)
    assert_equal(@div_1attrfilled2, (X.element(:div, lambda { "inside" }, {'a' => 'b'} ) { "also" }).to_s)

    #assert_raise(ArgumentError, 'hash only as first argument') { X.element(:div, "first", {'a' => 'b'}, "third") }
  end

  def test_method_missing
    assert_equal(X.div, X.element(:div))
    assert_equal(X.div(Jig::GAP), X.element(:div, Jig::GAP))
    assert_equal(X.div(Jig::GAP), X.element(:div, Jig::GAP))
    assert_equal(X.div(X.new), X.element(:div, X.new))

    assert_equal(X.div_, X.div)

    @div2 = "<div>\ninside</div>\n"
    assert_equal(@div2, X.element(:div, "inside").to_s)
    assert_equal(@div2, X.element(:div, "in", "side").to_s)

    # element with block
    assert_equal(@div2, (X.element(:div) {"inside"}).to_s)

    assert_equal(@div2, X.div("inside").to_s)
    assert_equal(@div2, X.div("in", "side").to_s)

    # div with attributes
    @div_empty = "<div>\n</div>\n"
    @div_1attr= %Q{<div a="b">\n</div>\n}
    @div_1attrfilled= %Q{<div a="b">\ninside</div>\n}
    @div_1attrfilled2= %Q{<div a="b">\ninsidealso</div>\n}
    assert_not_equal(@div_empty, X.div( 'a' => 'b').to_s)
    assert_equal(@div_1attr, X.div( 'a' => 'b').to_s)
    assert_equal(@div_1attrfilled, X.div( "inside", {'a' => 'b'} ).to_s)
    assert_equal(@div_1attrfilled, X.div( {'a' => 'b'}) { "inside" }.to_s)
    assert_equal(@div_1attrfilled, X.div(lambda { "inside" }, {'a' => 'b'} ).to_s)
    assert_equal(@div_1attrfilled2, (X.div(lambda { "inside" },  {'a' => 'b'}) { "also" }).to_s)

    # namespaces
    assert_match(/\A<a:div><\/a:div>/, A.div.to_s)
  end

  def test_more_plugging
    @div = "<div>\nabc</div>\n"
    @jdiv = X.new("<div>\nabc</div>\n")
    assert_equal(@div, @jdiv.to_s)
    assert_match(@jdiv, X.div << "abc")
    assert_match(@jdiv, X.div("abc"))
    assert_match(@jdiv, X.div { "abc" })

    @divp = "<div>\n<p>\n</p>\n</div>\n"
    @pdiv = "<p>\n<div>\n</div>\n</p>\n"
    @jdivp = X.new("<div>\n<p>\n</p>\n</div>\n")
    @jpdiv = X.new("<p>\n<div>\n</div>\n</p>\n")
    assert_equal(@divp, @jdivp.to_s)
    assert_equal(@pdiv, @jpdiv.to_s)
    assert_as_string(@jdivp, (X.div << X.p))
    assert_as_string(@jpdiv, X.p << X.div)

    @full = %Q{<div a="b">\ninside</div>\n}
    @full_jig = X.new(%Q{<div a="b">\ninside</div>\n})
    assert_equal(@full, @full_jig.to_s)
    assert_match(@full_jig, X.div('a' => 'b') { "inside" })
    assert_match(@full_jig, X.div("inside", {'a' => 'b'}))
  end


  def test_misc
    #assert_raise(ArgumentError, 'attribute must be string') { X.div('a' => :gap) << X.p }
    #assert_raise(ArgumentError) { ((X.div('a' => Jig::GAP) << X.p).to_s) }

    assert_equal( "ab", (X.new(:alpha, :beta) << {:alpha => 'a', :beta => 'b'}).to_s)
    assert_equal( "<div>\n</div>\n", (X.div).to_s)
    assert_not_equal( "ab", X.div.plug("ab").to_s)
    assert_equal( "<div>\nab</div>\n", X.div.plug("ab").to_s)

    #assert_equal( %Q{<div a="b">ab</div>\n}, X.div("a" => "b").to_s)
    assert_equal( %Q{<div a="b">\nfoo</div>\n}, X.div("a" => "b").plug("foo").to_s)

    # test plug nil
    # test plug with Hash
  end
end
