require 'jig'
require 'jig/xml'

class Jig
	# Jig::XHTML is a subclass of Jig::XML and is designed to assist in the
	# construction of XHTML documents.
  class XHTML < XML
    attr_accessor :extra
    protected :extra

    def initialize(*args)
      super
      @extra = {}
    end

    def initialize_copy(other)
      super
      @extra = other.extra.dup
    end

    def freeze
      @extra.freeze
      super
    end

    def eid
      extra[:eid]
    end

    def eid=(eid)
      raise RuntimeError, "no eid reassignment permitted" if extra[:eid]
      extra[:eid] = eid 
    end

    class <<self
      # Construct a jig for an XHTML element with _tag as the tag and include
      # an ID attribute with a guaranteed unique value.
			# Example:
			#			puts Jig::XHTML.element_with_id('div')		# <div id="x2354322">\n</div> 
      def element_with_id(tag, *args)
        attrs = { 'id' => :id }
        attrs = attrs.merge!(args.pop) if args.last.respond_to?(:fetch)
        args.push(Proc.new) if block_given?
        args.push attrs
        newjig = element(tag, *args)
        newjig.eid = "x#{newjig.object_id}"
        newjig.plug!(:id, newjig.eid )
      end

      # Construct a jig for an emtpy XHTML element with _tag as the tag and include
      # an ID attribute with a guaranteed unique value.  The selected id is
			# accessible via the eid attribute.
			# Example:
			#			j = Jig::XHTML.element_with_id('input', :name=>'login')
			#			puts j					# <input name="login" id="x2354328"/>
			#			puts j.eid			# x2354328
      def element_with_id!(tag, *args)
        attrs = { 'id' => :id }
        attrs = attrs.merge!(args.pop) if args.last.respond_to?(:fetch)
        args.push(Proc.new) if block_given?
        args.push attrs
        jig = element!(tag, *args)
        jig.eid = "x#{newjig.object_id}"
        jig.plug!(:id, jig.eid)
      end

			# Construct an element based on the method name.  If the method name
			# ends in '_with_id' or '_with_id!', the element is constructed with
			# a unique XML id attribute otherwise the Jig::XML element construction
			# rules apply.
      def method_missing(sym, *args, &block)
        text = sym.to_s
        if text.to_s =~ /_with_id!*$/
          element_with_id(text.sub(/_with_id!*$/,'').to_sym, *args, &block)
        else
          super
        end
      end

      DOCTYPES = {
        :strict, %{"-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"},
        :transitional, %{"-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"},
        :frameset, %{"-//W3C//DTD XHTML 1.0 Frameset//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd"}
      }

			# Construct an XHTML DOCTYPE declaration. The first argument, _dtype_, specifies
			# the type of document: :strict, :transitional, or :frameset.  Any additional
			# arguments are rendered after the DOCTYPE declaration.  A default gap is *not*
			# inserted if their are no arguments. Examples:
			#
			#	puts X.doctype(:strict)	# <!DOCTYPE html PUBLIC -//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd>
			# puts X.doctype(:strict).gaps.size    # 0
      def doctype(dtype, *args, &block)
        new(%{<!DOCTYPE html PUBLIC #{DOCTYPES.fetch(dtype)}>\n}, *args, &block)
      end

			# Construct a generic XHTML document.  If the first argument is a symbol it is
			# used to look up a matching DOCTYPE declaration (see #doctype).
			# X.xhtml						# transitional document with :title, :head, and :___
			# X.xhtml :strict		# strict document with :title, :head, and :___
			# X.xhtml :lang => 'jp'  # transition document with HTML attributes merged
			# X.xhtml(head, body)		 # transitional document with explicit head & body
      def xhtml(dtype=:transitional, *args, &block)
        if dtype.respond_to?(:fetch)
          dtype,*args = :transitional,dtype
        end
        attrs = {:lang=>'en', "xml:lang"=>'en', :xmlns=>'http://www.w3.org/1999/xhtml'}
        attrs.merge!(args.pop) if args.last.respond_to?(:fetch) 
        args.push(Proc.new) if block_given?
        args.push(head(title(:title),:head),body) if args.empty?
        args.push(attrs)
        doctype(dtype,html(*args))
      end

			# A convenience method for constructing an XHTML element with a named
			# CSS class and an unique XHTML element ID.
			# 
			#   X.container('span', 'urgent', 'This is urgent!')
			#			=> <span class="urgent" id="x2337852"></span>
      def container(tag, css, *args)
        args.push(Proc.new) if block_given?
        args.push(:class => css)
        jig = element_with_id(tag, *args)
        jig.send(:extra)[:css] = css
        jig
      end

			# An even shorter way to construct a div container
			#
			#   X.divc('urgent', 'This is urgent!')
			#			=> <div class="urgent" id="x2337852"></div>
      def divc(css_class, *args, &block)
        container(:div, css_class, *args, &block)
      end


			# Generate a link element for a favicon. Extra attributes
			# may be specified via the optional argument, _extra_.
			#
			#   X.link_favicon
			#			=> <link src="/favicon.ico" type="image/x-icon" rel="icon"/>
      def link_favicon(extra={})
        attrs = {:type=>"image/x-icon", :rel=>"icon", :src=>'/favicon.ico'}
        attrs.merge! extra
        link!(attrs)
      end

			# XXX: is this no longer needed?
      def normalize_args(args, attrs={}) # :nodoc"
        attrs.merge!(args.pop) if args.last.respond_to?(:fetch)
        args.push(Proc.new) if block_given?
        args.push INNER if args.empty?
        return args, attrs
      end

			# Generate a CSS style sheet element. If a 'src' attribute
			# is provided the contents is empty.  Without a 'src' attribute
			# a CDATA block wraps the contents of the element.
			#
			#   j = Jig::XHTML.style
			#   puts j.plug('/* CSS style sheet */')
			#
			#   <style media="all" type="text/css">
			#   <![CDATA[
			#   /* CSS style sheet */
			#    ]]>
			#   </style>
      def style(*args, &block)
        attrs = {:type=>"text/css", :media=>"all"}
        attrs.merge!(args.pop) if args.last.respond_to?(:fetch) 
        args.push(Proc.new) if block_given?
        if attrs.has_key?(:src)
          args = [attrs]
        else
          args = ["\n", cdata(*args.push("\n")), attrs]
        end
        element(:style, *args)
      end

			# Generate a script element.  XXX
			#
			#   j = Jig::XHTML.script
			#   puts j.plug(cdata("# the script"))
			#
			#   <script type=">
			#   <![CDATA[
			#   # the script
			#    ]]>
			#   </script>
      def script(*args, &block)
        attrs = args.pop if args.last.respond_to?(:fetch) 
        args.push(Proc.new) if block_given?
        if attrs.has_key?(:fetch)
          args = [attrs]
        else
          args.push(attrs)
        end
        element(:script, *args)
      end

      def input(*args, &block)
        element_with_id!(:input, *args, &block)
      end
      def textarea(*args, &block)
        element_with_id(:textarea, *args, &block)
      end
      def select(*args, &block)
        element_with_id(:select, *args, &block)
      end

      def more(ajig, bjig)
        body = div_with_id({:style => 'display: none'}, bjig)
        new(a({:href=>"#", :onclick => "toggle(#{body.eid})"}, '(details)'), body)
      end

			# Generate a Javascript comment.
			#
			#   j = Jig::XHTML.js_comment
			#   puts j.plug("comment")
			#
			#		/* comment */
      def js_comment(*args, &block)
        gap = Jig::Gap.new(:comment) { |*filling| 
          filling.map {|item| 
            item.to_s.split("\n").map {|line| "// #{line}" }
          }.join("\n")
        }
        new(gap, "\n").plug(:comment, *args)
      end

			# Generate a multiline Javascript comment.
			#
			#   j = Jig::XHTML.js_comments
			#   puts j.plug("line 1\nline 2")
			#
			#		/*
			#   line 1
			#   line 2
			#    */
      def js_mlcomment(*args, &block)
        new("/*\n", new(*args, &block), "\n */\n")
      end

			# Generate an inline script element for javascript.
			# The body of the script is wrapped in a CDATA block.
			#
			#   j = Jig::XHTML.javascript
			#   puts j.plug("// the script")
			#
			#   <script type="text/javascript" language="JavaScript">
			#   <![CDATA[
			#   // the script
			#    ]]>
			#   </script>
      def javascript(*args, &block)
        attrs = {:type=>"text/javascript", :language=>"JavaScript"}
        attrs.merge!(args.pop) if args.last.respond_to?(:fetch) 
        args.push(Proc.new) if block_given?
        script("//<![CDATA[\n", new(*args), "\n//]]>\n", attrs)
      end
    end
  end
end
