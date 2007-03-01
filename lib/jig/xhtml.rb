require 'jig'

class Jig

  module XHTML
    include XML
		def eid
			extra[:eid]
		end

		def eid=(eid)
			raise RuntimeError, "no eid reassignment permitted" if extra[:eid]
			extra[:eid] = eid 
		end
  end

	module XHTML::ClassMethods
    include XML::ClassMethods

		# Construct an HTML element using the method name as the element tag.
		def method_missing(symbol, *args, &block)
      constructor = :element
			text = symbol.to_s
			if text =~ /_with_id!*$/
				element_with_id(text.sub(/_with_id!*$/,'').to_sym, *args, &block)
			else
        if text =~ /!$/
          text.chop!
          constructor = :empty
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

		def container(tag, css, *args, &block)
			jig = element_with_id(tag, {:class => css}, *args, &block)
      jig.extra[:css] = css
      jig
		end

		def divc(css_class, *args, &block)
			container(:div, css_class, *args, &block)
		end

		# Construct a jig for an HTML element with _name_ as the tag and include
		# an ID attribute with a guaranteed unique value.
		def element_with_id(tag, *args, &block)
			attrs = { 'id' => :id }
			attrs.merge! args.shift if Hash === args.first
			newjig = element(tag, attrs, *args, &block)
			newjig.eid = "x#{newjig.object_id}"
			newjig.plug!(:id, newjig.eid )
		end

		# Construct a jig for an HTML element with _name_ as the tag and include
		# an ID attribute with a guaranteed unique value.
		def empty_with_id(tag, *args, &block)
			attrs = { 'id' => :id }
			attrs.merge! args.shift if Hash === args.first
			newjig = empty(tag, attrs, *args, &block)
			newjig.eid = "x#{newjig.object_id}"
			newjig.plug!(:id, newjig.eid )
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
      attrs = {:lang=>'en', :"xml:lang"=>'en', :xmlns=>'http://www.w3.org/1999/xhtml'}
      attrs.merge! args.shift if Hash === args.first
      args.push block if block
      args.push(head(title(:title),:head),body) if args.empty?
      doctype(dtype,html(attrs, *args))
    end

    def link_favicon(extra={})
      attrs = {:type=>"image/x-icon", :rel=>"icon", :src=>'/favicon.ico'}
      attrs.merge! extra
      link!(attrs)
    end

    def normalize_args(args=[], attrs={}, &block)
      attrs.merge! args.shift if Hash === args.first
      args.push block if block
      args.push GAP if args.empty?
      args.unshift attrs
      args
    end

    def style(*args, &block)
      attrs, *args = normalize_args(args, :type=>"text/css", :media=>"all", &block)
      p attrs
      p args
      args.push "\n"
      script(attrs, !attrs.has_key?(:src) && cdata(*args))
    end

    def script(*args, &block)
      attrs, *args = normalize_args(args, &block)
      element(:script, attrs, !attrs.has_key?(:src) && new(*args))
    end

		def input(*args, &block)
			empty_with_id(:input, *args, &block)
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
	end


end
