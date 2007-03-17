require 'jig'
require 'jig/xml'

class Jig
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
      # Construct a jig for an HTML element with _name_ as the tag and include
      # an ID attribute with a guaranteed unique value.
      def element_with_id(tag, *args)
        attrs = { 'id' => :id }
        attrs = attrs.merge!(args.pop) if args.last.respond_to?(:fetch)
        args.push(Proc.new) if block_given?
        args.push attrs
        newjig = element(tag, *args)
        newjig.eid = "x#{newjig.object_id}"
        newjig.plug!(:id, newjig.eid )
      end

      # Construct a jig for an HTML element with _name_ as the tag and include
      # an ID attribute with a guaranteed unique value.
      def element_with_id!(tag, *args)
        attrs = { 'id' => :id }
        attrs = attrs.merge!(args.pop) if args.last.respond_to?(:fetch)
        args.push(Proc.new) if block_given?
        args.push attrs
        jig = element!(tag, *args)
        jig.eid = "x#{newjig.object_id}"
        jig.plug!(:id, jig.eid)
      end

      DOCTYPES = {
        :strict, %{"-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"},
        :transitional, %{"-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"},
        :frameset, %{"-//W3C//DTD XHTML 1.0 Frameset//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd"}
      }

      def doctype(dtype, *args, &block)
        new(%{<!DOCTYPE html PUBLIC #{DOCTYPES.fetch(dtype)}>\n}, *args, &block)
      end

      def xhtml(dtype=:transitional, *args, &block)
        if dtype.respond_to?(:fetch)
          dtype,*args = :transitional,dtype
        end
        attrs = {:lang=>'en', :"xml:lang"=>'en', :xmlns=>'http://www.w3.org/1999/xhtml'}
        attrs.merge!(args.pop) if args.last.respond_to?(:fetch) 
        args.push(Proc.new) if block_given?
        args.push(head(title(:title),:head),body) if args.empty?
        args.push(attrs)
        doctype(dtype,html(*args))
      end

      def container(tag, css, *args)
        args.push(Proc.new) if block_given?
        args.push(:class => css)
        jig = element_with_id(tag, *args)
        jig.send(:extra)[:css] = css
        jig
      end

      def divc(css_class, *args, &block)
        container(:div, css_class, *args, &block)
      end


      def link_favicon(extra={})
        attrs = {:type=>"image/x-icon", :rel=>"icon", :src=>'/favicon.ico'}
        attrs.merge! extra
        link!(attrs)
      end

      def normalize_args(args, attrs={})
        attrs.merge!(args.pop) if args.last.respond_to?(:fetch)
        args.push(Proc.new) if block_given?
        args.push INNER if args.empty?
        return args, attrs
      end

      def style(*args, &block)
        attrs = {:type=>"text/css", :media=>"all"}
        attrs.merge!(args.pop) if args.last.respond_to?(:fetch) 
        args.push(Proc.new) if block_given?
        if attrs.has_key?(:src)
          args = [attrs]
        else
          args = [cdata(*args.push("\n")), attrs]
        end
        element(:style, *args)
      end

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

      def js_comment(*args, &block)
        gap = Jig::Gap.new(:comment) { |*filling| 
          filling.map {|item| 
            item.to_s.split("\n").map {|line| "// #{line}" }
          }.join("\n")
        }
        new(gap, "\n").plug(:comment, *args)
      end

      def js_mlcomment(*args, &block)
        new("/*\n", new(*args, &block), "\n */\n")
      end

      def javascript(*args, &block)
        attrs = {:type=>"text/javascript", :language=>"JavaScript"}
        attrs.merge!(args.pop) if args.last.respond_to?(:fetch) 
        args.push(Proc.new) if block_given?
        script("//<![CDATA[\n", new(*args), "\n//]]>\n", attrs)
      end
    end
  end
end
