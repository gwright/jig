
require 'jig'
require 'test/jig'
require 'test/unit'

class TestParse < Test::Unit::TestCase
  J = Jig
  include Asserts
  def test_string
    source = "chunky bacon"
    j = Jig.parse(source)
    assert_equal(source, j.to_s)
  end

  def test_with_newline 
    source = "before %{:alpha:} after\n"
    j = Jig.parse(source)
    assert_equal([:alpha], j.gaps)
    assert_equal("before ", j[0].to_s)
    assert_equal(" after\n", j[2].to_s)
  end

  def test_gap
    source = "chunky %{:adjective:} bacon"
    j = Jig.parse(source)
    assert_equal([:adjective], j.gaps)
    assert_equal("chunky ", j[0].to_s)
    assert_equal(" bacon", j[2].to_s)
  end

  def test_agap
    source = "<input%{=type,itype=} />"
    j = Jig::XML.parse(source)
    assert_equal([:itype], j.gaps)
    assert_equal("<input", j[0].to_s)
    assert_equal(" />", j[2].to_s)
    jp = j.plug(:itype => 'password')
    assert_equal("<input type=\"password\" />", jp.to_s)
  end

  def test_agap_error
    source = "<input%{=type=} />"
    assert_raise(ArgumentError) { Jig::XHTML.parse(source) }
  end

  def test_jig_agap_error
    source = "<input%{=type,itype=} />"
    assert_raise(ArgumentError) { Jig.parse(source) }
  end

  def test_syntax_error
    source = "%{ , # invalid syntax }"
    assert_raise(ArgumentError) { Jig.parse(source) }
  end

  def test_lgap
    a = 2
    j = Jig.parse("%{!a + 1!}", binding)
    assert_equal("3", j.to_s)
  end

  def test_lgap_error
    j = Jig.parse("%{!b + 1!}")
    assert_raise(NameError) { j.to_s }
  end

  def test_yield
    j = Jig.parse("%{!yield + 1!}") { 5 }
    assert_equal("6", j.to_s)
  end

  def test_instance_binding
    klass = Class.new {
      def to_jig
        Jig.parse("secret: %{!secret!}", binding)
      end
      def secret
         "xyzzy"
      end
      private :secret
    }
    
    instance = klass.new
    assert_raise(NoMethodError) { instance.secret }
    assert_equal("secret: xyzzy", instance.to_jig.to_s)
  end
end

