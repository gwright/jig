require 'jig'

class Jig
	Encode = Hash[*%w{& amp " quot > gt < lt}]
	Base = {}

	def self.escape(target)
		unless Jig === target 
			target = Jig.new(target.to_s.gsub(/[#{Encode.keys.join}]/) {|m| "&#{Encode[m]};" })
		end
		target
	end

	# Element ID: 
	def eid
		extra[:eid]
	end

	def eid=(eid)
		raise RuntimeError, "no eid reassignment permitted" if extra[:eid]
		extra[:eid] = eid 
	end

	class <<self
		def container(tag, css, *args, &block)
			extra[:css] = css
			element_with_id(tag, {:class => extra[:css]}, *args, &block)
		end

		def divc(css_class, *args, &block)
			container(:div, css_class, *args, &block)
		end

		# Construct a jig for an HTML element with _name_ as the tag.
		def element(name='div', *args, &block)
			if Hash === args.first
				attrs = args.shift 
				base = (new("<#{name}", attrs, ">", GAP, "</#{name}>\n"))
			else
				base = (Base[name.to_s] ||=  new("<#{name}>", GAP, "</#{name}>\n"))
			end
			items = []
			items[0,0] = block if block
			items[0,0] = args unless args.empty?
			items[0,0] = GAP unless items.size > 1
			base.plug new(*items)
		end

		# Construct a jig for an HTML element with _name_ as the tag and include
		# an ID attribute with a guaranteed unique value.
		def element_with_id(tag, *args, &block)
			idhash = { 'id' => :id }
			if Hash === args.first
				idhash.update args.shift
			end
			newjig = element( tag, idhash, *args, &block)
			newjig.eid = "x#{newjig.object_id}"
			newjig.plug!(:id, newjig.eid )
		end

		def input(*args, &block)
			element_with_id(:input, *args, &block)
		end
		def textarea(*args, &block)
			element_with_id(:textarea, *args, &block)
		end
		def select(*args, &block)
			element_with_id(:select, *args, &block)
		end

		def more(ajig, bjig)
			body = Jig.div_with_id({:style => 'display: none'}, bjig)
			Jig[Jig.a({:href=>"#", :onclick => "toggle(#{body.eid})"}, '(details)'), body]
		end

		# Construct an HTML element using the method name as the element tag.
		def method_missing(symbol, *args, &block)
			text = symbol.to_s
			if text =~ /_with_id$/
				element_with_id(text.sub(/_with_id$/,'').to_sym, *args, &block)
			elsif text =~ /_$/
				# XXX: not sure why this is here
				element(text.chop, *args, &block)
			else
				element(symbol, *args, &block)
			end
		end
	end
end
