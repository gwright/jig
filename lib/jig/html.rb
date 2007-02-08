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
			items = (Base[name] ||= ["<#{name}>", "</#{name}>\n"]).dup
			args.push block if block
			if Hash === args.first
		  	attrs = args.shift 
		   	items[0,1] = ["<#{name}", attrs, ">"]
			end
			if args.empty?
				items[-1,0] = GAP
			else
		  	items[-1,0] = args
			end
		  new(*items)
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
