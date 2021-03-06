require 'jig'

class Jig
=begin rdoc
 Jig::XML is a subclass of Jig designed to simplify construction of
 strings containing XML text.  Several class methods are defined to
 construct standard XML elements.  Unknown class method calls are
 interpreted as XML element constructions:

   j = Jig::XML.xml               
   j.inspect         # => #<Jig: ["<?xml", " version=\"1.0\"", " ?>\n"]>
   j.to_s            # => <?xml version="1.0" ?>\n

   j = Jig::XML.book(Jig::XMLtitle('War and Peace'))
   j.inspect         # => #<Jig: ["<book", nil, ">", "<title", nil, ">\n", "War and Peace", "</title>\n", "</book>\n"]>
   j.to_s            # => <book><title>\nWar and Peace</title>\n </book>
   
 For most element constructors, arguments to the constructor are inserted as
 the contents of the element.  An optional block argument is inserted as a
 proc.  If there are no arguments and no block, the element is constructed
 with the default gap, :___, as its contents. XML attributes are specified by
 passing a Hash as the final argument.  See the Attributes section below for
 a detailed description of attribute processing.
 Examples:
 
    X = Jig::XHTML
    puts X.span('some text')            # <span>some text</span>

    puts X.h3('rendered at: ') do       # <h3>rendered at: Mon Apr 16 23:02:13 EDT 2007</h3>
      Time.now
    end

    j = X.p
    puts j                              # <p>\n</p>
    puts j.plug('Four score...')        # <p>Four score...\n</p>

 =Attributes

 A hash passed as a final argument to an XML element constructor is interpreted
 as potential XML attributes for the element.  Each key/value pair is considered 
 seperately.  Pairs are processed as follows:
 * a nil value causes the pair to be silently discarded
 * a symbol value causes an attribute gap to be inserted into the XML element
 * a gap value is inserted as is into the XML element attribute area, the key is discarded in this case (XXX)
 * a proc is inserted as a deferred attribute
 * a jig is inserted as deferred attribute
 * any other value is inserted as an attribute with the value converted via #to_s

 =Attribute Gaps

 If an attribute gap remains unfilled it will not appear in the rendered jig.  When
 an attribute gap is filled, the result is processed as described for the key/value
 pairs of a hash.

 =Deferred Attributes
 
 A deferred attribute is not finalized until the jig is rendered via #to_s. If a
 deferred proc evaluates to nil, the attribute pair is silently discarded otherwise
 the resulting value is converted to a string and an XML attribute is rendered.
 A deferred jig is rendered and the result used as the XML attribute value.

   X = Jig::XHTML
   X.div('inner', :class => 'urgent')           # => <div class="urgent">inner</div>
   j = X.div('inner', :class => :class)         # => <div>inner</div>
   j.plug(:class, 'urgent')                     # => <div class="urgent">inner</div>
   j.plug(:class, nil)                          # => <div>inner</div>
   
   j = X.input(:type => :type)                  # => <input/>
   j.plug(:type, "")                            # => <input type="" />
   j.plug(:type, 'password')                    # => <input type="password" />

   css = nil
   j = X.div('inner', :class => proc { css })   # => <div>inner</div>
   css = 'urgent'
   j.to_s                                       # => <div class="header">inner</div>

   color = Jig.new('color: ', { %w{reb blue green}[rand(3)] }
   j = X.div('inner', :style=> color)           # => <div style="color: red">inner</div>
   j.to_s                                       # => <div style="color: green">inner</div>
=end

  class ALGap < Gap
    def fill(h)
      h && h.map { |k,v| Jig::XML.attribute(k, v) }
    end
  end

  class AGap < Gap
    attr_accessor :aname

    def initialize(name, aname)
      super(name)
      self.aname = aname
    end

    def fill(fill)
      Jig::XML.attribute(aname, fill)
    end
  end

  class XML < Jig
    # Converts _hash_ into attribute value pairs and pushes them
    # on the end of the jig.
    def push_hash(hash)
      push(*hash.map { |k,v| self.class.attribute(k, v) })
    end
    protected :push_hash

    class <<self
      # These elements will have newlines inserted into the default constructions to 
      # increase the readability of the generated XML.
      Newlines = [:html, :head, :body, :title, :div, :p, :table, :script, :form] 
      Encode = Hash[*%w{& amp " quot > gt < lt}] # :nodoc:
      Entities = Encode.keys.join # :nodoc:

      # Prepare +aname+ and +value+ for use as an attribute pair in an XML jig:
      # * If +value+ is nil or false, the empty string is returned.
      # * If +value+ is a symbol, an attribute gap is returned.
      # * If +value+ is a gap, the gap is returned.
      # * If +value+ is a proc, method or jig, the construction of the attribute 
      #   is deferred by wrapping it in a proc inside a jig.
      # * Otherwise, +aname+ and +value+ are converted to strings and rendered as an XML
      #   attribute pair.
      # Examples:
      #   attribute('value', :firstname)                  # => Gap.new(:firstname) {...}
      #   attribute('type', 'password')                   # => 'type="password"'
      #   attribute('type', nil)                          # => ''
      #   attribute('lastname', 'Einstein')               # => 'lastname="Einstein"'
      #   a = attribute('lastname', Jig.new('Einstein'))  # => #<Jig: [#<Proc:0x00058624>]>
      #   a.to_s                                          # => 'lastname="Einstein"'
      #   b = attribute('lastname', Jig.new { })          # => #<Jig: [#<Proc:0x000523dc]>
      #   b.to_s                                          # => ''
      #   c = attribute('lastname', Jig.new {""})         # => #<Jig: [#<Proc:0x00055a3c]>
      #   c.to_s                                          # => 'lastname=""'
      def attribute(aname, value)
        case value
        when nil, false
          ""
        when Symbol
          AGap.new(value, aname)
          #Gap.new(value) { |fill| attribute(aname, fill) }
        when Gap
          value
        when Proc, Method
          Jig.new { attribute(aname, value.call) }
        when Jig
          Jig.new { attribute(aname, value.to_s) }
        else
          " #{aname}=\"#{value}\""
        end
      end

      # In addition to the parsing done by Jig.parse, Jig::XML.parse recognizes and 
      # constructs attribute gaps from text of the form: %{=attribute,gapname=}
      #   Jig.parse("<input%{=type,itype} />").plug(:itype, 'password')   # <input type="password" />
      def parse(*)
        super
      end

      # Returns a new string with <, >, and & converted to their HTML entity codes.
      def escape(target)
        new(target.to_s.gsub(/[#{Entities}]/) {|m| "&#{Encode[m]};" })
      end

      # Extend Jig.parse to recognize attribute gaps as %{=attrname,gapname=}.
      # An attribute gap is returned.
      def parse_other(delim, stripped)
        if delim == '='
          if stripped =~ /\A(.*),(.*)\z/
            new({ $1 => $2.to_sym})
          else
            raise ArgumentError, "invalid gap syntax: #{quoted}"
          end
        else
          super
        end
      end
      private :parse_other

      ATTRS = Gap::ATTRS # :nodoc:
      ATTRS_GAP = Jig::ALGap.new(ATTRS)
      #ATTRS_GAP = Gap.new(ATTRS) { |h| h && h.map { |k,v| Jig::XML.attribute(k, v) } } # :nodoc:

      Element_Cache = {} # :nodoc:
      # Construct a generic XML element with two gaps:
      # * +:__a+ filters a hash into an XML attribute list
      # * +:___+ which is a default gap
      # Jig::XML._element('div')      # => #<Jig: ["<div", :"__a{}", ">\n", :___, "</div>\n"]>
      def _element(tag) 
        Element_Cache[tag] ||= begin
          whitespace = Newlines.include?(tag.to_sym) && "\n" || ""
          new("<#{tag}".freeze, ATTRS_GAP, ">#{whitespace}".freeze, GAP, "</#{tag}>\n".freeze).freeze
        end
      end

      # Construct a generic XML element with four gaps:
      # * +:__a+ filters a hash into an XML attribute list
      # * +:___+ which is a default gap
      # * +tag+ which acts a placeholder for the element's opening and closing tag
      # Jig::XML._element(:tag)      # => #<Jig: ["<", :tag, :"__a{}", ">\n", :___, "</", :tag, ">\n"]>
      def _anonymous(tag) # :nodoc:
        whitespace = Newlines.include?(tag.to_sym) && "\n" || ""
        new("<", tag.to_sym, ATTRS_GAP, ">#{whitespace}", GAP, "</", tag.to_sym, ">\n")
      end

      Empty_Element_Cache = {} # :nodoc:
      # Construct an XML empty element with one gap:
      # * +:__a+ filters a hash into an XML attribute list
      # * +:___+ which is a default gap
      # Jig::XML._element!('br')      # => #<Jig: ["<br", :"__a{}", "/>"]>
      def _element!(tag) # :nodoc:
        Empty_Element_Cache[tag] ||= begin
          new("<#{tag}".freeze, ATTRS_GAP, "/>\n".freeze).freeze
        end
      end

      # Construct an HTML element using the method name as the element tag.
      # If a method ends with '!', the element is constructed as an empty element.
      # If a method ends with '?', the element is constructed as an anonymous element.
      # If a method ends with '_', it is stripped and the result used as a the tag.
      # If a method contains an '_', it is converted to a ':' to provide XML namespace tags.
      # If a method contains an '__', it is converted to a single '_'.
      #
      # Jig::XML.div.to_s        # => "<div></div>"
      # Jig::XML.div_.to_s       # => "<div></div>"
      # Jig::XML.br!to_s         # => <br />"
      # Jig::XML.heading?        # => Jig["<", :heading, ">", :___, "</", :heading, ">"]
      # Jig::XML.xhtml_h1        # => "<xhtml:h1></xhtml:h1>"
      # Jig::XML.xhtml__h1       # => "<xhtml_h1></xhtml_h1>"
      def method_missing(symbol, *args, &block)
        constructor = :element
        text = symbol.to_s

        if text =~ /!\z/
          text.chop!
          constructor = :element!
        elsif text =~ /\?\z/
          text.chop!
          constructor = :anonymous
        end

        if text =~ /_$/    # alternate for clashes with existing methods
          text.chop!
        end

        if text =~ /_/
          # Single _ gets converted to : for XML name spaces
          # Double _ gets converted to single _
          text = text.gsub(/([^_])_([^_])/){|x| "#{$1}:#{$2}"}.gsub(/__/, '_')
        end

        if self != Jig::XML and self != Jig::XHTML
          namespace = name.split('::').last.downcase
          text = "#{namespace}:#{text}"
        end
        send(constructor, text, *args, &block)
      end

      # Construct an anonymous XML element. The single argument provides a name for a
      # gap that replaces the XML start and end tags.  Use plug to replace the gaps
      # with an actual tag.
      #
      #   a = anonymous(:heading)       # => #<Jig: ["<", :heading, ">", :___, "</", :heading, ">\n"]>
      #   b = a.plug(:heading, 'h1')    # => #<Jig: ["<", "h1", ">", :___, "</", "h1", ">\n"]>
      #   b.plug('contents')            # => #<Jig: ["<", "h1", ">", "contents", "</", "h1", ">\n"]>
      def anonymous(tag='div', *args)
        attrs = args.last.respond_to?(:fetch) && args.pop || nil
        args.push(lambda{|*x| yield(*x) }) if block_given?
        args.push GAP if args.empty?
        _anonymous(tag).plug(ATTRS => attrs, GAP => args)
      end

      # Construct a standard XML element with +tag+ as the XML tag
      # and a default gap for the contents of the element.
      #   Jig::XML.element('h1')                    # => #<Jig: ["<h1", ">", :___, "</h1>\n"]>
      #   Jig::XML.element('p', :class => 'body')   # => #<Jig: ["<p", "class=\"body\"", ">", :___, "</h1>\n"]>
      def element(tag='div', *args)
        attrs = args.last.respond_to?(:fetch) && args.pop || nil
        args.push(lambda(&Proc.new)) if block_given?
        args.push GAP if args.empty?
        _element(tag).plug(ATTRS => attrs, GAP => args)
      end

      # Construct a standard XML empty element with _tag_ as the XML tag.
      #
      #   Jig::XHTML.element!('br')              # => '<br />'
      #
      #   h = { :name => 'year', :maxsize => 4, :type => :type }
      #
      #   j = Jig::XHTML.element!('input', h)    # => '<input name="year" maxsize="4"/>'
      #   j.plug(:type => 'hidden')              # => '<input name="year" maxsize="4" type="hidden"/>'
      def element!(tag, *args)
        attrs = args.last.respond_to?(:fetch) && args.pop || nil
        _element!(tag).plug(ATTRS => attrs, GAP => nil)
      end

      # Construct an XML declaration tag.
      #
      #   Jig::XML.xml                   # => '<?xml version="1.0">'
      #   Jig::XML.xml(:lang => 'jp')    # => '<?xml version="1.0" lang="jp">'
      def xml(*args)
        attrs = { :version => '1.0' }
        attrs.merge!(args.pop) if args.last.respond_to?(:fetch) 
        args.push(lambda{|*x| yield(*x) }) if block_given?
        new("<?xml", attrs, " ?>\n", *args)
      end

      Cache = {} # :nodoc:
      # Construct a CDATA block
      # 
      #   Jig::XML.cdata('This data can have < & >')
      #
      #   <![CDATA[
      #   This data can have < & > ]]>
      def cdata(*args)
        args.push(lambda{|*x| yield(*x) }) if block_given?
        args.push GAP if args.empty?
        jig = (Cache[:cdata] ||= new("<![CDATA[\n".freeze, GAP, " ]]>\n".freeze).freeze)
        jig.plug(GAP, *args)
      end

      # Construct an XML comment element.
      #
      #   Jig::XML.comment("This is a comment")
      # 
      #   \<!-- This is a comment -->
      def comment(*args)
        #:stopdoc:
        args.push(lambda{|*x| yield(*x) }) if block_given?
        args.push GAP if args.empty?
        jig = (Cache[:comment] ||= new("<!-- ".freeze, GAP, " -->\n".freeze).freeze)
        jig.plug(GAP, *args)
        #:startdoc:
      end

      # Construct a multiline XML comment element.
      #
      #   Jig::XML.comment("first line\nsecond line")
      #   
      #   \<!-- 
      #   first line
      #   second line
      #   -->
      def comments(*args)
        args.push(lambda{|*x| yield(*x) }) if block_given?
        args.push GAP if args.empty?
        args.push "\n"
        comment("\n", *args)
      end
    end # class <<self
  end # class XML
end # module Jig
