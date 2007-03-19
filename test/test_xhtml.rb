require 'jig'
require 'test/unit'
require 'test/jig'

class TestXML < Test::Unit::TestCase
  XH = Jig::XHTML
  include Asserts

  def test_eid
    @div = %r{<div id="[^"]*">\n</div>\n}
    @input = %r{<input id="\w*"/>}
    @jig_div_id = XH.div_with_id
    @jig_input = XH.input!
    assert_match(@div, @jig_div_id.to_s)
    assert_raise(RuntimeError,'eid reassignment') { @jig_div_id.eid = "foo" }
    assert_match(@input, XH.input.to_s)
    assert_not_equal(XH.li_with_id.to_s, XH.li_with_id.to_s)
  end

  def test_element_with_id
    j = XH.element_with_id(:a, :href => "foo")
    id, href = %Q{id="#{j.eid}"}, 'href="foo"'
    assert_match(%r{<a (#{id} #{href}|#{href} #{id})></a>\n}, j.to_s)
  end

end
