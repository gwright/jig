require 'jig'

class Jig
	module XML
		# Element ID: 
		def push_hash(hash)
			push(*hash.map { |k,v| self.class.attribute(k, v) })
		end
		protected :push_hash

	end

  module XML::ClassMethods
    Newlines = [:html, :head, :body, :title, :div, :p, :table, :script, :form]
		Encode = Hash[*%w{& amp " quot > gt < lt}]

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

    def _anonymous(tag)
      whitespace = Newlines.include?(tag.to_sym) && "\n" || ""
      new("<", tag.to_sym, ATTRS_GAP, ">#{whitespace}", INNER, "</", tag.to_sym, ">\n")
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
        if text =~ /!\z/
          text.chop!
          constructor = :element!
        elsif text =~ /\?\z/
          text.chop!
          constructor = :anonymous
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
		def anonymous(tag='div', *args)
      attrs = args.last.respond_to?(:fetch) && args.pop || nil
      args.push(lambda{|*x| yield(*x) }) if block_given?
      args.push INNER if args.empty?
      _anonymous(tag).plug(ATTRS => attrs, INNER => args)
    end

		# Construct a jig for an HTML element with _tag_ as the tag.
		def element(tag='div', *args)
      attrs = args.last.respond_to?(:fetch) && args.pop || nil
      args.push(lambda{|*x| yield(*x) }) if block_given?
      args.push INNER if args.empty?
      _element(tag).plug(ATTRS => attrs, INNER => args)
    end

		# Construct a jig for an empty HTML element with _tag_ as the tag.
		def element!(tag, *args)
      attrs = args.last.respond_to?(:fetch) && args.pop || nil
      args.push(lambda{|*x| yield(*x) }) if block_given?
      args.push INNER if args.empty?
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
