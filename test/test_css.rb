
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
      @gaps = [:__s, :__ps, :__p]
    end
    def test_empty_rule
      assert_as_string(' {}', Cjig.rule, 'no selector')
      assert_equal(@gaps, Cjig.rule.gap_list, 'two gaps with new rule')
    end
		def test_rule
      assert_as_string('div {}', Cjig.rule('div'), 'type selector')
      assert_as_string('div p {}', Cjig.rule('div p'), 'string as selector')
      assert_equal(@gaps, Cjig.rule('div').gap_list, 'selector and plist gaps available')
    end

    def test_plist
      assert_as_string('div {color: red; }', Cjig.rule('div', :color => 'red'), 'explicit plist')
      red = Cjig.rule('div').plist(:color => 'red')
      assert_as_string('div {color: red; }', red, 'added plist')
      assert_equal(@gaps, red.gap_list, 'plist leaves gaps')
      background, color = 'background: olive; ', 'color: red; '
      assert_as_string(/div \{(#{color}#{background}|#{background}#{color})\}/, 
        @div.plist(:color => 'red', :background => 'olive'),
        'added plist')
      assert_as_string('div {color: red; background: olive; }', 
        @div.plist(:color => 'red').plist(:background => 'olive'),
        'plist twice')

      blue = Cjig.rule('div') | {:color => 'blue'}
      assert_as_string('div {color: blue; }', blue, 'plist merge via |')
    end

    def test_open?
      assert(Cjig.div.open?, 'gaps remain')
      assert(!Cjig.div.plug_all.open?, 'no gaps')
    end

    def test_method_missing
      assert_as_string('div {}', Cjig.div, 'unknown method generates type selector')
      assert_equal(@gaps, Cjig.div.gap_list, 'unknown method generates rule jig')
    end

    def test_universal_selector
      assert_as_string('* {}', Cjig.us, 'universal selector')
    end

    def test_empty_selector
      assert_as_string(' {}', Cjig.null , 'empty selector')
    end
    def test_descendent_selector
      assert_as_string('h1 li {}', Cjig.h1 >> Cjig.li , 'descendent selector')
    end

    def test_child_selector
      assert_as_string('div > h1 {}', Cjig.div > Cjig.h1, 'child selector')
    end

    def test_sibling_selector
      assert_as_string('div + h1 {}', Cjig.div + Cjig.h1, 'sibling selector')
    end

    def test_id_selector
      assert_as_string('div#home {}', Cjig.div * Cjig.home, 'id selector')
    end

    def test_pseudo_selector
      assert_as_string('div:home {}', Cjig.div % Cjig.home, 'pseudo selector')
    end

    def test_class_selector
      assert_as_string('h1.urgent {}', Cjig.h1.urgent, 'class selector')
    end
    def test_attribute_selector
      assert_as_string('h1[class] {}', Cjig.h1['class'], 'attribute selector')
    end
    def test_exact_attribute_selector
      assert_as_string('h1[class="urgent"] {}', Cjig.h1['class' => "urgent"], 'exact attribute selector')
    end
    def test_partial_attribute_selector
      assert_as_string('h1[class~="urgent"] {}', Cjig.h1['class' => /urgent/], 'partial attribute selector')
    end
    def test_language_attribute_selector
      assert_as_string('h1[lang|="lc"] {}', Cjig.h1[:lang => /lc/], 'language attribute selector')
    end

    def test_selector_list
      assert_as_string('h1, h2 {}', Cjig.h1.group(Cjig.h2), 'selector list')
      assert_as_string('h1, h2, h3 {}', Cjig.h1.group(Cjig.h2, Cjig.h3), 'selector list')
    end

    def test_units
      units = [:in, :cm, :mm, :pt, :pc, :em, :ex, :px]
      units.each {|u| assert_equal("1#{u}", 1.send(u)) }
      assert_equal("50%", 50.pct)
      assert_equal("50.00%", 0.5.pct)
      assert_equal("99.99%", 0.9999.pct)
    end

    def test_plist_merge
      div = Cjig.div 
      h1 = Cjig.h1(:color => 'red')
      result = div * h1
      pairs = [[:>>, ' '], [:>, ' > '], [:+, ' + '], [:*, '#'], [:%, ':']]
      pairs.each { |op, text|
        assert_as_string("div#{text}h1 {color: red; }", div.send(op, h1))
      }
      assert_as_string("div[onclick] {color: red; }", div['onclick'] |{:color => 'red'})
      assert_as_string("div[onclick] {color: red; background: blue; }", div['onclick'].|(:color => 'red')|{:background => 'blue'})
    end

    def test_selector
      assert_as_string("div", Cjig.div.selector)
      assert_as_string("div, h1", Cjig.group(Cjig.div, Cjig.h1).selector)
    end

    def test_declarations
      assert_as_string("", Cjig.div.declarations)
      assert_as_string("color: red; ", (Cjig.div |{'color' => 'red'}).declarations)
    end
	end
end
