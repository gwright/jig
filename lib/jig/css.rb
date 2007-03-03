
require 'jig'

class Jig
	module CSS
		# Element ID: 
		def push_hash(hash)
			push(*hash.map { |k,v| self.class.attribute(k, v) })
		end
		protected :push_hash

    def plist(plist)
      declarations = plist.map { |k,v| "#{k}: #{v}; " }.join
      before(:__p, declarations)
    end

    # Construct a selector with the current selector as the parent
    # and the other selector as the child.
    # 
    #   (div > p).to_s     # 'div > p {}'
    def >(other)
      before(:__s, ">", other.slice(0))
    end

    def +(other)
      p other
      before(:__s, "+", other.slice(0))
    end

    def -(other)
      before(:__s, "#", other.slice(0))
    end

    def -@
      self.class.new("#", self)
    end

    def >>(other)
      before(:__s, " ", other.slice(0))
    end

    def method_missing(sym)
      if sym.to_s =~ /\A_(.*)/
        before(:__s, ":#{$1}")
      else
        before(:__s, ".#{sym}")
      end
    end

    def [](*args)
      if args.size == 1 && args.first.respond_to?(:to_hash) && args.first.size == 1
        k,v = *args.first.to_a.first
        case v
        when String
          before(:__s, %Q{[#{k}="#{v}"]})
        when Regexp
          if k.to_s == 'lang'
            before(:__s, %Q{[lang|="#{v}"]})
          else
            before(:__s, %Q{[#{k}~="#{v.to_s.split(':').last.chop}"]})
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
      base = new(:__s, ' {', :__p, '}')
      declarations = plist && plist.map { |k,v| "#{k}: #{v}; " }.join
      base = base.before(:__s, selector) if selector
      base = base.before(:__p, declarations) if declarations
      base
    end

    # Generate a universal selector rule
    def us(*args)
      rule('*', *args)
    end

    def ___
      rule
    end

    def method_missing(sym, *args)
      rule(sym.to_s, *args)
    end

  end
end
=begin
		# Convert the name, value pair into an attribute gap.
		def attribute(aname, value)
			if Symbol === value
				Gap.new(value) { |fill| aplug(aname, fill) }
			elsif Gap === value
				value
			else
				aplug(aname, value)
			end
		end
    module_function :attribute
    public :attribute

		# If value is false, return null string.
		# Otherwise render name and value as an XML attribute pair:
		#
		# If value is not a Jig and is not a Proc, the string is constructed and returned.
		# A Proc or a Jig, which may indirectly reference a Proc, is handled by constructing
		# a lambda that responds to _to_s_.  The evaluation of the Proc or Jig is thus delayed
		# until _to_s_ is called.
		def aplug(name, value)
			return "" unless value
			return " #{name}=\"#{value}\"" unless value.respond_to?(:call) or Jig === value
			if Jig === value
				jig, value = value, lambda { jig.to_s }
			end
			future = lambda do
				if v = value.call
					%Q{ #{name}="#{v}"}
				else
					""
				end
			end
			def future.to_s; call; end
			future
		end
		private :aplug
    module_function :aplug

    ATTRS = Gap::ATTRS
    ATTRS_GAP = Gap.new(ATTRS) { |h| h && h.map { |k,v| attribute(k, v) } }

	  def escape(target)
		  unless Jig === target 
			  target = new(target.to_s.gsub(/[#{Encode.keys.join}]/) {|m| "&#{Encode[m]};" })
		  end
		  target
	  end

    Element_Cache = {}
    def _element(tag)
      whitespace = Newlines.include?(tag.to_sym) && "\n" || ""
      Element_Cache[tag] ||= begin
        new("<#{tag}".freeze, ATTRS_GAP, ">#{whitespace}".freeze, INNER, "</#{tag}>\n".freeze).freeze
      end
    end

    Empty_Element_Cache = {}
    def _element!(tag)
      Empty_Element_Cache[tag] ||= begin
        new("<#{tag}".freeze, ATTRS_GAP, "/>\n".freeze).freeze
      end
    end

		# Construct an HTML element using the method name as the element tag.
		def method_missing(symbol, *args, &block)
      constructor = :element
			text = symbol.to_s
			if text =~ /_with_id!*$/
				element_with_id(text.sub(/_with_id!*$/,'').to_sym, *args, &block)
			else
        if text =~ /!$/
          text.chop!
          constructor = :element!
        end
				if text =~ /_$/		# alternate for clashes with existing methods
					text.chop!
        end
				if text =~ /_/
					# Single _ gets converted to : for XML name spaces
					# Double _ gets converted to single _
					text = text.gsub(/([^_])_([^_])/){|x| "#{$1}:#{$2}"}.gsub(/__/, '_')
				end
			  send(constructor, text, *args, &block)
			end
		end

		# Construct a jig for an HTML element with _tag_ as the tag.
		def element(tag='div', *args)
      attrs = args.last.respond_to?(:fetch) && args.pop || nil
      args.push(lambda{|*x| yield(*x) }) if block_given?
      _element(tag).plug(ATTRS => attrs, INNER => args)
    end

		# Construct a jig for an empty HTML element with _tag_ as the tag.
		def element!(tag, *args)
      attrs = args.last.respond_to?(:fetch) && args.pop || nil
      args.push(lambda{|*x| yield(*x) }) if block_given?
      _element!(tag).plug(ATTRS => attrs, INNER => args)
		end

    def xml(*args)
			attrs = { :version => '1.0' }
      attrs.merge!(args.pop) if args.last.respond_to?(:fetch) 
      args.push(lambda{|*x| yield(*x) }) if block_given?
      new("<?xml", attrs, "?>\n", *args)
    end

    Cache = {}
    def cdata(*args)
      args.push(lambda{|*x| yield(*x) }) if block_given?
      args.push INNER if args.empty?
      jig = (Cache[:cdata] ||= new("<![CDATA[\n".freeze, INNER, " ]]>\n".freeze).freeze)
      jig.plug(*args)
    end

    def comment(*args)
      args.push(lambda{|*x| yield(*x) }) if block_given?
      args.push INNER if args.empty?
      jig = (Cache[:comment] ||= new("<!-- ".freeze, INNER, " -->\n".freeze).freeze)
      jig.plug(*args)
    end

    def comments(*args)
      args.push(lambda{|*x| yield(*x) }) if block_given?
      args.push INNER if args.empty?
      args.push "\n"
      comment("\n", *args)
    end
  end
end
=end
