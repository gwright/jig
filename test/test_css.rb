
require 'jig'
require 'test/unit'
require 'test/jig'

CSS = Jig::CSS

class CSS
	class TestCSS < Test::Unit::TestCase
    include Asserts
    def setup
      @div = CSS.new('div')
      @gaps = [:__s, :__ds, :__de]
    end
    def test_default
      assert_as_string('* {}', CSS.new, 'no selector')
      assert_equal(@gaps, CSS.new.gaps, 'two gaps with new rule')
    end

		def test_new
      assert_as_string('div {}', CSS.new('div'), 'type selector')
      assert_as_string('div p {}', CSS.new('div p'), 'string as selector')
      assert_equal(@gaps, CSS.new('div').gaps, 'selector and declarations gaps available')
    end

    def test_declarations
      assert_as_string('div {color: red; }', CSS.new('div', :color => 'red'), 'explicit plist')
      red = CSS.new('div') | {:color => 'red'}
      assert_as_string('div {color: red; }', red, 'added plist')
      assert_equal(@gaps, red.gaps, 'plist leaves gaps')
      background, color = 'background: olive; ', 'color: red; '
      assert_as_string(/div \{(#{color}#{background}|#{background}#{color})\}/, 
        @div | {:color => 'red', :background => 'olive'},
        'added declarations')
      assert_as_string('div {color: red; background: olive; }', 
        @div | {:color => 'red'} | {:background => 'olive'},
        'two declarations')

      blue = CSS.new('div') | {:color => 'blue'}
      assert_as_string('div {color: blue; }', blue, 'declaration list merge via &')
    end

    def test_open?
      assert(CSS.div.open?, 'gaps remain')
      assert(CSS.div.plug.closed?, 'no gaps')
      assert(!CSS.div.plug.open?, 'no gaps')
    end

    def test_method_missing
      assert_as_string('div {}', CSS.div, 'unknown method generates type selector')
      assert_equal(@gaps, CSS.div.gaps, 'unknown method generates new jig')
    end

    def test_universal_selector
      assert_as_string('* {}', CSS.new, 'universal selector')
    end

    def test_descendent_combinator
      assert_as_string('h1 li {}', CSS.h1 >> CSS.li , 'descendent combinator')
    end

    def test_child_combinator
      assert_as_string('div > h1 {}', CSS.div > CSS.h1, 'child combinator')
    end

    def test_sibling_combinator
      assert_as_string('div + h1 {}', CSS.div + CSS.h1, 'sibling combinator')
    end

    def test_id_selector
      assert_as_string('div#home {}', CSS.div * 'home', 'id selector')
    end

    def test_pseudo_selector
      assert_as_string('div:home {}', CSS.div/'home', 'pseudo selector')
    end

    def test_class_selector
      assert_as_string('h1.urgent {}', CSS.h1.urgent, 'class selector')
    end
    def test_attribute_selector
      assert_as_string('h1[class] {}', CSS.h1['class'], 'attribute selector')
    end
    def test_exact_attribute_selector
      assert_as_string('h1[class="urgent"] {}', CSS.h1['class' => "urgent"], 'exact attribute selector')
    end
    def test_partial_attribute_selector
      assert_as_string('h1[class~="urgent"] {}', CSS.h1['class' => /urgent/], 'partial attribute selector')
    end
    def test_language_attribute_selector
      assert_as_string('h1[lang|="lc"] {}', CSS.h1[:lang => /lc/], 'language attribute selector')
    end

    def test_selector_list
      assert_as_string('h1, h2 {}', CSS.h1.merge(CSS.h2), 'selector list')
      assert_as_string('h1, h2 {}', CSS.h1 | CSS.h2, 'selector list operator')
      assert_as_string('h1, h2, h3 {}', CSS.h1.merge(CSS.h2).merge(CSS.h3), 'selector list')
      assert_as_string('*, h1 {}', CSS.new | CSS.h1, 'adding to the default rule')
    end

    def test_units
      units = [:in, :cm, :mm, :pt, :pc, :em, :ex, :px]
      units.each {|u| assert_equal("1#{u}", 1.send(u)) }
      assert_equal("50%", 50.pct)
      assert_equal("50.00%", 0.5.pct)
      assert_equal("99.99%", 0.9999.pct)
    end

    def test_declarations_merge
      div = CSS.div 
      h1 = CSS.h1(:color => 'red')
      result = div * h1
      args = [[:>>, ' ', h1], [:>, ' > ', h1], [:+, ' + ', h1]]
      args.each { |op1, text, arg2|
        assert_as_string("div#{text}h1 {color: red; }", div.send(op1, arg2))
      }
      args = [[:*, '#', 'header'], [:/, ':', 'first-child']]
      args.each { |op1, text, arg2|
        assert_as_string("div#{text}#{arg2} {}", div.send(op1, arg2))
      }
      assert_as_string("div[onclick] {color: red; }", div['onclick'] |{:color => 'red'})
      assert_as_string("div[onclick] {color: red; background: blue; }", div['onclick'].|(:color => 'red')|{:background => 'blue'})
    end

    def test_extract_selector
      assert_as_string("div", CSS.div.selector)
      assert_as_string("div, h1", (CSS.div | CSS.h1).selector)
    end

    def test_extract_declarations
      assert_as_string("", CSS.div.declarations)
      assert_as_string("color: red; ", (CSS.div |{'color' => 'red'}).declarations)
    end

    def test_declartion_with_gaps
      redgap = CSS.div | {'color' => :red }
      assert(redgap.gaps.include?(:red))
      assert_as_string('div {}', redgap , 'gap for property value')
      assert_as_string('div {color: red; }', redgap.plug(:red, 'red'), 'plug gap')
    end

	end
end
