
require 'jig'

class Jig
	module CSS
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

    # When the CSS module is add the helper methods to core
    def self.included(other)
      Integer.send(:include, IntegerHelper)
      Float.send(:include, FloatHelper)
    end

    def plist(plist=nil)
      declarations = plist && plist.inject([]) { |d, (k,v)| 
        k = k.to_s.tr('_','-')
        case v
        when Array
          d << "#{k}: #{v.join(', ')}; "
        else
          d << "#{k}: #{v}; "
        end
      }
      if plist
        before(:__p, *declarations) 
      else
        self
      end
    end

    # Construct a selector with the current selector as the parent
    # and the other selector as the child.
    # 
    #   (div > p).to_s     # 'div > p {}'
    def >(other)
      before(:__s, " > ", other.selector).before(:__p, other.declarations)
    end

    def +(other)
      before(:__s, " + ", other.selector).before(:__p, other.declarations)
    end

    def *(other)
      before(:__s, "#", other.selector).before(:__p, other.declarations)
    end

    def %(other)
      before(:__s, ":", other.selector).before(:__p, other.declarations)
    end

    def >>(other)
      before(:__s, " ", other.selector).before(:__p, other.declarations)
    end

    def group(*others)
      others.inject(self) { |jig, other|
        jig.before(:__s, ", ", other.selector).before(:__p, other.declarations)
      }
    end

    def |(pl)
      plist(pl)
    end

    def selector
      self.class.new(slice(0))
    end

    def declarations
      self.class.new(slice(2))
    end

    def method_missing(sym, plist=nil)
      before(:__s, ".#{sym}").plist(plist)
    end

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

  module CSS::ClassMethods
    Newlines = [:html, :head, :body, :title, :div, :p, :table, :script, :form]
		Encode = Hash[*%w{& amp " quot > gt < lt}]

    def rule(selector="", plist=nil)
      #base = (@_rule ||= new(:__s, " {\n", :__ps, :__p, "}").freeze)
      base = (@_rule ||= new(:__s, " {", :__ps, :__p, "}").freeze)
      base = base.before(:__s, selector) if selector
      base.plist(plist)
    end

    # Generate a universal selector rule
    def us(*args)
      rule('*', *args)
    end

    def ___
      rule
    end

    def group(*selectors)
      selectors.inject {|list, sel| list.group(sel) }
    end

    def method_missing(sym, *args)
      rule(sym.to_s, *args)
    end

  end
end
