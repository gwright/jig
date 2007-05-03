
require 'jig'

class Jig
  # Jig::CSS is a subclass of Jig designed to facilitate the 
  # construction of CSS rule sets. This class should be considered 
  # experimental.  The documentation uses C instead Jig::CSS to
  # simplify the examples.
  #
  # An instance of Jig::CSS represents a CSS rule consisting of 
  # a selector list and an associated declaration block.  The 
  # selector list or the delcaration block or both may be empty. 
  # Declarations are specified via a hash.
  #
  #   C.new                         # => {}
  #   C.new('h1')                   # => h1 {}
  #   C.new(nil, 'color' => 'red')  # => {color: red; }
  #
  # A simple CSS type selector with an empty declaration is the 
  # default construction:
  #
  #   C.div                         # => div {}
  #   C.li                          # => li {}
  #
  # Rules can be combined with each other or with a hash via the 
  # 'pipe' operator.
  #
  #   big = { 'font-size' => '24pt' }
  #   bold = { 'font-weight' => 'bold' }
  #   big_div = C.div | big                 # => div {font-size: 24pt; }
  #   big_bold_div = bigger | bold          # => div {font-size: 24pt; font-weight: bold; }
  #   C.h1 | C.h2                           # => h1, h2 { }
  #   C.h1 | big | C.h2 | bold              # => h1, h2 { font-size: 24pt; font-weight: bold; }
  class CSS < Jig
    module IntegerHelper
      def in; "#{self}in"; end
      def cm; "#{self}cm"; end
      def mm; "#{self}mm"; end
      def pt; "#{self}pt"; end
      def pc; "#{self}pc"; end
      def em; "#{self}em"; end
      def ex; "#{self}ex"; end
      def px; "#{self}px"; end
      def pct; "#{self}%"; end
    end

    module FloatHelper
      def pct; "%.2f%%" % (self*100); end
    end

    Integer.class_eval { include IntegerHelper }
    Float.class_eval { include FloatHelper }

    Newlines = [:html, :head, :body, :title, :div, :p, :table, :script, :form]
    Encode = Hash[*%w{& amp " quot > gt < lt}]

    class <<self
      # Construct a simple type selector based on the method name.
      #   C.new('div')    # => div {}
      #   C.div           # => div {}
      def method_missing(sym, *args)
        new(sym.to_s, *args)
      end

      def media(*types)
        indent = Gap.new(:___) { |text| Jig.new { text.to_s.split("\n").map { |line| "  #{line}" }.join("\n")}  }
        Jig.new("@media #{types.join(', ')} {\n", indent, "\n}\n")
      end

      def import(url, *types)
        Jig.new("@import url(\"#{url}\") #{types.join(', ')}")
      end
    end

    # Construct a CSS rule.
    def initialize(selector='*', declarations=nil)
      super(selector, :__s, " {", :__ds, to_declarations(declarations),  :__de, "}").freeze
    end

    def to_declarations(hash)
      return nil unless hash
      hash.inject(Jig.null) do |djig, (property, value)| 
        djig.push(
          case value
            when Gap
              value
            when Symbol
              Gap.new(value) { |fill| declaration(property, fill) }
            else
              declaration(property, value)
          end
        )
      end
    end

    # Convert property/value pair for use in a CSS rule jig.
    # Any underscores in the property are converted to hyphens.
    # If the property ends in '!', the '!' is stripped and the
    # declaration is marked with the CSS keyword '!important'.
    # * If +value+ is nil or false, the empty string is returned.
    # * If +value+ is a symbol, a declaration gap is returned.
    # * If +value+ is a gap, the gap is returned.
    # * If +value+ is a proc, method, or jig, a deferred 
    #   declaration gap is returned by wrapping the construction 
    #   in a lambda in a jig.
    # * If the +value+ is an array, it is converted to a string
    #   via #join.  If the property is 'font-family', the values
    #   are joined with a comma, otherwise a space is used.
    # * Otherwise property and value are converted to strings and
    #   a CSS declaration string is returned.
    def declaration(property, value)
      case value
      when nil, false
        ""
      when Symbol
        Gap.new(value) { |fill| declaration(property, fill) }
      when Gap
        value
      when Jig
        Jig.new { declaration(property, value.to_s) }
      when Proc, Method
        Jig.new { declaration(property, value.call) }
      when Array
        seperator = (property == 'font[-_]family' ? ", " : " ")
        declaration(property, value.join(seperator))
      else
        property.to_s =~ /\A(.*[^!])(!?)\z/
        property = $1.to_s.tr('_','-')
        "#{property}: #{value}#{" !important" unless $2.empty?}; "
      end
    end

    # Construct a child selector.  The parent is the lhs selector and
    # the child is the rhs selector.
    #   div > p     # => "div > p {}"
    def >(other)
      before(:__s, " > ", other.selector).before(:__de, other.declarations)
    end

    # Construct an adjacent sibling selector.  The first sibling is 
    # the lhs selector and the other sibling is rhs selector.
    #   h1 + p     # => "h1 + p {}"
    def +(other)
      before(:__s, " + ", other.selector).before(:__de, other.declarations)
    end

    # Construct a general sibling selector.  The first sibling is 
    # the lhs selector and the other sibling is rhs selector.
    #   div ~ p     # => "div ~ p {}"
    def ~(other)
      before(:__s, "~", other.selector).before(:__de, other.declarations)
    end

    # Construct an id selector.  The id is the rhs value.
    #   h1 * 'chapter-one'     # => "h1#chapter-one {}"
    def *(id)
      before(:__s, "#", id.to_s)
    end

    # Construct a pseudo-selector.
    #   h1/:first_letter      # => "h1:first-letter {}"
    #   a/:active             # => "a:active {}"
    def /(pseudo)
      before(:__s, ":", pseudo.to_s)
    end

    # Construct a descendent selector.  The parent is the lhs selector and
    # the descendent is the rhs selector.
    #   div >> p     # => "div p {}"
    def >>(other)
      before(:__s, " ", other.selector).before(:__de, other.declarations)
    end

    # Construct a negation pseudo class.  The delcarations associated
    # with the other selector are discarded.
    #   div - p     # => "div:not(p) {}"
    def -(other)
      before(:__s, ":not(", other.selector, ")")
    end

    # Construct a nth_child pseudo class.
    def nth_child(a=0,b=0)
      before(:__s, ":nth-child(#{a}n+#{b})")
    end

    # Construct a nth_last_child pseudo class.
    def nth_last_child(a=0,b=0)
      before(:__s, ":nth-last-child(#{a}n+#{b})")
    end

    # Construct a nth-of-type pseudo class.
    def nth_of_type(a=0,b=0)
      before(:__s, ":nth-of-type(#{a}n+#{b})")
    end

    # Construct a nth-last-of-type pseudo class.
    def nth_last_of_type(a=0,b=0)
      before(:__s, ":nth-last-of-type(#{a}n+#{b})")
    end

    # Construct a lang pseudo class.
    def lang(lang)
      before(:__s, ":lang(#{lang})")
    end

    # Merge this rule with another object. 
    # * If the other object is a hash, the hash is converted 
    #   to a CSS declaration list and merged with the current list. 
    # * If the other object is a rule, the other selectors and 
    #   declarations are merged with the current selectors and 
    #   declarations. 
    # * Any other object is assumed to be a selector string 
    #   and is merged with the current selectors.
    #
    # C.div.merge(:color => 'red')            # => div { color: red; }
    # C.div.merge(C.h1)                       # => div, h1 {}
    # C.div(:color => 'blue').merge(C.h1(:font_size => '10pt'))
    #                                         # => div, h1 { color: blue; font-size: 10pt }
    # C.div.merge('h1, h2, h3')               # => div, h1, h2, h3 {}
    def merge(other)
      return self unless other
      case other
      when Hash
        before(:__de, to_declarations(other)) 
      when self.class
        before(:__s, ", ", other.selector).before(:__de, other.declarations)
      else
        before(:__s, ", ", other)
      end
    end

    def to_jig
      Jig.new(plug( :__s => nil, :__de => nil, :__ds => nil ))
    end

    alias | :merge

    # Extract the selector list from the rule as a jig.
    #   (div | h1).selector     # => Jig["div, h1"]
    def selector
      slice(0...index(:__s))
    end

    # Extract the declaration list from the rule.  The list is returned as
    # a jig and not as a hash.
    #   div(:color => 'red').declarations   # => Jig["color: red; ", :__de]
    def declarations
      slice(index(:__ds)+1..index(:__de)-1)
    end

    # Missing methods are rewritten as calls to #class_, which
    # constructs class selectors.
    #   C.div.class_('urgent')        # => div.urgent {}
    #   C.div.urgent                  # => div.urgent {}
    #   C.div.note.caution            # => div.note.caution {}
    def method_missing(sym, declarations=nil)
      class_(sym, declarations)
    end

    # Add a class selector to pending selector.  Usually
    # this method is called indirectly via method_missing.
    #   C.div.class_('urgent')        # => div.urgent {}
    #   C.div.urgent                  # => div.urgent {}
    def class_(klass, declarations=nil)
      before(:__s, ".#{klass}") | declarations
    end

    # Construct an attribute selector. If the argument is a
    # simple string a simple attribute selector is constructed. If
    # the argument is a hash with a string as the value, an exact
    # attribute selector is constructed.  If the value is a regular 
    # expression, a partial attribute selector is constructed. If 
    # the key is the literal string 'lang', a language attribute 
    # selector is constructed.
    #
    #   input[:type]                # => input[type] {}
    #   input[:type => 'password']  # => input[type="password"] {}
    #   input[:lang => 'en']        # => input[lang|="en"] {}
    #   input[:class => /heading/]  # => input[class=~"heading"] {}
    def [](*args)
      if args.size == 1 && args.first.respond_to?(:to_hash) && args.first.size == 1
        k,v = *args.first.to_a.first
        case v
        when String
          before(:__s, %Q{[#{k}="#{v}"]})
        when Regexp
          v = v.to_s.split(':').last.chop    # strip out the processing flags
          if k.to_s == 'lang'
            before(:__s, %Q{[lang|="#{v}"]})
          else
            before(:__s, %Q{[#{k}~="#{v}"]})
          end
        else
          self
        end
      elsif args.size == 1 && args.first.respond_to?(:to_s)
        before(:__s, "[#{args.first}]")
      else
        self
      end
    end

  end
end
