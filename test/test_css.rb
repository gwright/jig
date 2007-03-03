
require 'jig'
require 'test/unit'

class Cjig < Jig
  enable :CSS
end

module Asserts
  def assert_as_string(expected, jig, message='')
    case expected
    when String
      assert_equal(expected, jig.to_s, message)
    when Regexp
      assert_match(expected, jig.to_s, message)
    end
  end
end

class Cjig
	class TestCSS < Test::Unit::TestCase
    include Asserts
    def setup
      @div = Cjig.rule('div')
    end
    def test_empty_rule
      assert_as_string(' {}', Cjig.rule, 'no selector')
      assert_equal([:__s, :__p], Cjig.rule.gap_list, 'two gaps with new rule')
    end
		def test_rule
      assert_as_string('div {}', Cjig.rule('div'), 'type selector')
      assert_as_string('div p {}', Cjig.rule('div p'), 'string as selector')
      assert_equal([:__s, :__p], Cjig.rule('div').gap_list, 'selector and plist gaps available')
    end

    def test_plist
      assert_as_string('div {color: red; }', Cjig.rule('div', :color => 'red'), 'explicit plist')
      red = Cjig.rule('div').plist(:color => 'red')
      assert_as_string('div {color: red; }', red, 'added plist')
      assert_equal([:__s, :__p], red.gap_list, 'plist leaves gaps')
      background, color = 'background: olive; ', 'color: red; '
      assert_as_string(/div \{(#{color}#{background}|#{background}#{color})\}/, 
        @div.plist(:color => 'red', :background => 'olive'),
        'added plist')
      assert_as_string('div {color: red; background: olive; }', 
        @div.plist(:color => 'red').plist(:background => 'olive'),
        'plist twice')
    end

    def test_open?
      assert(Cjig.div.open?, 'gaps remain')
      assert(!Cjig.div.plug_all.open?, 'no gaps')
    end

    def test_method_missing
      assert_as_string('div {}', Cjig.div, 'unknown method generates type selector')
      assert_equal([:__s, :__p], Cjig.div.gap_list, 'unknown method generates rule jig')
    end

    def test_universal_selector
      assert_as_string('* {}', Cjig.us, 'universal selector')
    end

    def test_empty_selector
      assert_as_string(' {}', Cjig.___ , 'empty selector')
    end
    def test_descendent_selector
      assert_as_string('p li {}', Cjig.p >> Cjig.li , 'descendent selector')
    end

    def test_child_selector
      assert_as_string('div>p {}', Cjig.div > Cjig.p, 'child selector')
    end

    def test_sibling_selector
      assert_as_string('div+p {}', Cjig.div + Cjig.p, 'sibling selector')
    end

    def test_id_selector
      assert_as_string('div#home {}', Cjig.div - Cjig.home, 'id selector')
    end
    def test_id_selector
      assert_as_string('#home {}', -Cjig.home, 'id selector')
    end
    def test_class_selector
      assert_as_string('p.urgent {}', Cjig.p.urgent, 'class selector')
    end
    def test_attribute_selector
      assert_as_string('p[class] {}', Cjig.p['class'], 'attribute selector')
    end
    def test_exact_attribute_selector
      assert_as_string('p[class="urgent"] {}', Cjig.p['class' => "urgent"], 'exact attribute selector')
    end
    def test_partial_attribute_selector
      assert_as_string('p[class~="urgent"] {}', Cjig.p['class' => /urgent/], 'partial attribute selector')
    end
	end
end
