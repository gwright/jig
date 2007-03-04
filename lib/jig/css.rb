
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

    def to_declarations(hash)
      hash.inject(Jig.null) { |d, (k,v)| 
        v = case v
        when Gap
          v
        when Symbol
				  Gap.new(v) { |fill| property_plug(k, fill) }
        else
          property_plug(k, v)
        end
        d.push(v)
      }
    end
    module_function :to_declarations

		# If value is false, return null string.
		# Otherwise render name and value as an XML attribute pair:
		#
		# If value is not a Jig and is not a Proc, the string is constructed and returned.
		# A Proc or a Jig, which may indirectly reference a Proc, is handled by constructing
		# a lambda that responds to _to_s_.  The evaluation of the Proc or Jig is thus delayed
		# until _to_s_ is called.
		def property_plug(property, value)
			return "" unless value
      property = property.to_s.tr('_','-')
      future = now = nil
			if value.respond_to?(:call)
        future = lambda do
          if result = value.call
            property_plug(property, result)
          else
            ""
          end
        end
      elsif Jig === value
        future = lambda { value.to_s }
      elsif Array === value
        now = "#{property}: #{value.join(', ')}; "
      else
        now = "#{property}: #{value}; "
      end
      if future
			  def future.to_s; call; end
      end
			now || future
		end
		private :property_plug
    module_function :property_plug

    # Construct a selector with the current selector as the parent
    # and the other selector as the child.
    # 
    #   (div > p).to_s     # 'div > p {}'
    def >(other)
      before(:__s, " > ", other.selector).before(:__de, other.declarations)
    end

    def +(other)
      before(:__s, " + ", other.selector).before(:__de, other.declarations)
    end

    def *(id)
      before(:__s, "#", id.to_s)
    end

    def %(pseudo)
      before(:__s, ":", pseudo.to_s)
    end

    def >>(other)
      before(:__s, " ", other.selector).before(:__de, other.declarations)
    end

    def group(other)
      return self unless other
      sep = selector.null? ? "" : ", "
      case other
      when Hash
        before(:__de, to_declarations(other)) 
      when self.class
        before(:__s, sep, other.selector).before(:__de, other.declarations)
      else
        before(:__s, sep, other)
      end
    end

    def &(other)
      group(other)
    end

    def |(pl)
      group(pl)
    end

    def selector
      self.class.new(slice(0))
    end

    def declarations
      s,e = index(:__ds),index(:__de)
      self.class.new(slice((s+1)..e))
    end

    def method_missing(sym, plist=nil)
      before(:__s, ".#{sym}") & plist
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

    def rule(selector=nil, plist=nil)
      base = (@_rule ||= new(:__s, " {", :__ds, :__de, "}").freeze)
      base & selector | plist
    end

    # Generate a universal selector rule
    def us(*args)
      rule('*', *args)
    end

    def group(*selectors)
      selectors.inject {|list, sel| list.group(sel) }
    end

    def method_missing(sym, *args)
      rule(sym.to_s, *args)
    end

  end
end
