require 'jig'

class Jig
  # Jig::XML is a subclass of Jig designed to simplify construction of
  # strings containing XML elements.
  #
  # Expression             
  # Jig.xml               
  #           => #<Jig: ["<?xml", " version=\"1.0\"", " ?>\n"]>
  #
  # Jig.comment("sample")  
  #           => #<Jig: ["<!-- ", "sample", " -->\n"]>
  #
  # Jig.book(Jig.title('War and Peace'))
  #           => #<Jig: ["<book", nil, ">", "<title", nil, ">\n", "War and Peace", "</title>\n", "</book>\n"]>

  class XML < Jig
    # Converts _hash_ into attribute value pairs and pushes them
    # on the end of the jig.
    def push_hash(hash)
      push(*hash.map { |k,v| self.class.attribute(k, v) })
    end
    protected :push_hash

    class <<self
      Newlines = [:html, :head, :body, :title, :div, :p, :table, :script, :form]
      Encode = Hash[*%w{& amp " quot > gt < lt}]

      # Prepare _aname_ and _value_ for use as an attribute pair in an XML jig.
      # If _value_ is a symbol or Gap, an attribute gap is returned.  The
      # construction of the XML attribute string in this case is deferred until
      # the gap is plugged and is handled by the attribute gap itself.
      # 
      # If _value_ is neither a symbol or a Gap, the pair is passed to aplug
      # to be converted to a string or jig if necessary. See the aplug for
      # details.
      #
      #   attribute('value', :firstname)       Gap.new(:firstname) { ... }
      #   attribute('type', 'password')        'type="password"'
      #   attribute('type', nil)               ''
      def attribute(aname, value)
        if Symbol === value
          Gap.new(value) { |fill| aplug(aname, fill) }
        elsif Gap === value
          value
        else
          aplug(aname, value)
        end
      end

      # Returns an object that evaluates to an XML attribute specification when
      # to_s is called.  The null string is returned if value is determined to
      # be false or nil.
      #
      # If value is not true, returns the null string immediately.
      # If value is neither a jig nor an object that responds to _call_, the 
      # corresponding XML attribute specification is constructed and returned.
      # 
      # If value is a proc or a jig then the construction of the XML attribute must be
      # deferred. In this case a jig is returned.   When rendered, the jig will
      # evaluate value and return an attribute specification if value is true. 
      # Otherwise the the jig will render as a null string.
      #
      #   aplug('lastname', 'Einstein')               'lastname="Einstein"'
      #   aplug('lastname', nil)                      ''
      #   as = aplug('lastname', Jig.new('Einstein')
      #   as.to_s                                     'lastname="Einstein"'
      #   as = aplug('lastname', Jig.new { 
      def aplug(name, value)
        return "" unless value
        return " #{name}=\"#{value}\"" unless value.respond_to?(:call) or Jig === value
        Jig.new do
          value = value.call if value.respond_to?(:call)
          value && %Q{ #{name}="#{value}"} || ""
        end
      end
      private :aplug
      #module_function :aplug

      ATTRS = Gap::ATTRS
      ATTRS_GAP = Gap.new(ATTRS) { |h| h && h.map { |k,v| Jig::XML.attribute(k, v) } }

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
          new("<#{tag}".freeze, ATTRS_GAP, ">#{whitespace}".freeze, GAP, "</#{tag}>\n".freeze).freeze
        end
      end

      def _anonymous(tag)
        whitespace = Newlines.include?(tag.to_sym) && "\n" || ""
        new("<", tag.to_sym, ATTRS_GAP, ">#{whitespace}", GAP, "</", tag.to_sym, ">\n")
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
        args.push GAP if args.empty?
        _anonymous(tag).plug(ATTRS => attrs, GAP => args)
      end

      # Construct a jig for an HTML element with _tag_ as the tag.
      def element(tag='div', *args)
        attrs = args.last.respond_to?(:fetch) && args.pop || nil
        args.push(lambda{|*x| yield(*x) }) if block_given?
        args.push GAP if args.empty?
        _element(tag).plug(ATTRS => attrs, GAP => args)
      end

      # Construct a jig for an empty HTML element with _tag_ as the tag.
      def element!(tag, *args)
        attrs = args.last.respond_to?(:fetch) && args.pop || nil
        args.push(lambda{|*x| yield(*x) }) if block_given?
        args.push GAP if args.empty?
        _element!(tag).plug(ATTRS => attrs, GAP => args)
      end

      def xml(*args)
        attrs = { :version => '1.0' }
        attrs.merge!(args.pop) if args.last.respond_to?(:fetch) 
        args.push(lambda{|*x| yield(*x) }) if block_given?
        new("<?xml", attrs, " ?>\n", *args)
      end

      Cache = {}
      def cdata(*args)
        args.push(lambda{|*x| yield(*x) }) if block_given?
        args.push GAP if args.empty?
        jig = (Cache[:cdata] ||= new("<![CDATA[\n".freeze, GAP, " ]]>\n".freeze).freeze)
        jig.plug(GAP, *args)
      end

      def comment(*args)
        args.push(lambda{|*x| yield(*x) }) if block_given?
        args.push GAP if args.empty?
        jig = (Cache[:comment] ||= new("<!-- ".freeze, GAP, " -->\n".freeze).freeze)
        jig.plug(GAP, *args)
      end

      def comments(*args)
        args.push(lambda{|*x| yield(*x) }) if block_given?
        args.push GAP if args.empty?
        args.push "\n"
        comment("\n", *args)
      end
    end # class <<self
  end # class XML
end # module Jig
