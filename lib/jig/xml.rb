require 'jig'

class Jig
	module Xml
		# Element ID: 
		def push_hash(hash)
			push(*hash.map { |k,v| to_attr(k, v) })
		end
		protected :push_hash

		# Convert the name, value pair into an attribute gap.
		def to_attr(aname, value)
			if Symbol === value
				Gap.new(value) { |fill| aplug(aname, fill) }
			elsif Gap === value
				value
			else
				aplug(aname, value)
			end
		end
		private :to_attr

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
	end

  module Xhtml
    include Xml
		def eid
			extra[:eid]
		end

		def eid=(eid)
			raise RuntimeError, "no eid reassignment permitted" if extra[:eid]
			extra[:eid] = eid 
		end
  end

  module Xml::ClassMethods
	  def escape(target)
		  unless Jig === target 
			  target = new(target.to_s.gsub(/[#{Encode.keys.join}]/) {|m| "&#{Encode[m]};" })
		  end
		  target
	  end

		# Construct a jig for an HTML element with _tag_ as the tag.
		def element(tag='div', *args, &block)
			args.push block if block
			items = (Cache[tag] ||= ["<#{tag}>".freeze, "</#{tag}>\n".freeze]).dup
			if Hash === args.first
		  	attrs = args.shift 
		   	items[0,1] = (Cache4[tag] ||= ["<#{tag}".freeze, ">".freeze]).dup
		   	items[1,0] = attrs
			end
			if args.empty?
				items[-1,0] = GAP
			else
		  	items[-1,0] = args
			end
		  new(*items)
		end

		# Construct a jig for an empty HTML element with _tag_ as the tag.
		def empty(tag, *args, &block)
			args.push block if block
			if args.empty?
        items = (Cache2[tag] ||= ["<#{tag}/>\n".freeze]).dup
			else
        items = (Cache3[tag] ||= ["<#{tag}".freeze, "/>\n".freeze]).dup
		  	items[-1,0] = args
			end
		  new(*items)
		end

    def xml(*args, &block)
			attrs = { 'version' => '1.0' }
			attrs.merge! args.shift if Hash === args.first
      new("<?xml", attrs, "?>\n}", new(*args, &block))
    end

    def cdata(*args, &block)
      args.push block if block
      args.push GAP if args.empty?
      args.unshift "\n//<![CDATA[\n"
      args.push "\n//]]>\n"
      new(*args)
    end
  end

	module Xhml::ClassMethods
    include Xml::ClassMethods
		Cache = {}
    Cache2 = {}
    Cache3 = {}
    Cache4 = {}
		Encode = Hash[*%w{& amp " quot > gt < lt}]

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
			extra[:css] = css
			element_with_id(tag, {:class => extra[:css]}, *args, &block)
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

    def xhtml(*args, &block)
      new(%Q{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">\n},
        new(*args, &block))
    end
    def html(*args, &block)
      attrs = {:lang=>'en', :"xml:lang"=>'en', :xmlns=>'http://www.w3.org/1999/xhtml'}
      if Hash === args.first
        attrs.merge! args.shift
      end
      args.push GAP if args.empty?
      element(:html, attrs, *args, &block)
    end

    def xml_comment(*args, &block)
      args.push block if block
      args.push GAP if args.empty?
      args.unshift "<!-- "
      args.push " -->\n"
      new(*args)
    end

    def js_comment(*args, &block)
      args.push block if block
      args.push GAP if args.empty?
      args.unshift "// "
      args.push "\n"
      new(*args)
    end

    def js(*args, &block)
      attrs = {:type=>"text/javascript", :language=>"JavaScript"}
      if Hash === args.first
        attrs.merge! args.shift
      end
      args.push block if block
      args.push GAP if args.empty?
      script(attrs, cdata(*args))
    end

    def link_favicon(extra={})
      attrs = {:type=>"image/x-icon", :rel=>"icon", :src=>'/favicon.ico'}
      attrs.merge! extra
      link!(attrs)
    end

    def style(*args, &block)
      attrs = {:type=>"text/css", :media=>"all"}
      if Hash === args.first
        attrs.merge! args.shift
      end
      args.push block if block
      args.push GAP if args.empty?
      jig = script(attrs)
      unless attrs.has_key? :src
        jig << cdata(*args)
      end
      jig
    end

    def js_comments(*args, &block)
      args.push block if block
      args.push GAP if args.empty?
      args.unshift "/* "
      args.push "*/\n"
      new(*args)
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
