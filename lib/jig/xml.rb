require 'jig'

class Jig
	module XML
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

  module XML::ClassMethods
		Cache = {}
    Cache2 = {}
    Cache3 = {}
    Cache4 = {}
    Newlines = [:html, :head, :body, :title, :div, :p, :table, :script, :form]
		Encode = Hash[*%w{& amp " quot > gt < lt}]

	  def escape(target)
		  unless Jig === target 
			  target = new(target.to_s.gsub(/[#{Encode.keys.join}]/) {|m| "&#{Encode[m]};" })
		  end
		  target
	  end

		# Construct a jig for an HTML element with _tag_ as the tag.
		def element(tag='div', *args, &block)
      whitespace = Newlines.include?(tag.to_sym) && "\n" || ""
			args.push block if block
			items = (Cache[tag] ||= [%Q{<#{tag}>#{whitespace}}.freeze, "</#{tag}>\n".freeze]).dup
			if Hash === args.first
		  	attrs = args.shift 
		   	items[0,1] = (Cache4[tag] ||= ["<#{tag}".freeze, ">#{whitespace}".freeze]).dup
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
			attrs = { :version => '1.0' }
			attrs.merge! args.shift if Hash === args.first
      new("<?xml", attrs, "?>\n", new(*args, &block))
    end

    def cdata(*args, &block)
      args.push block if block
      args.push GAP if args.empty?
      args.unshift "<![CDATA[\n"
      args.push " ]]>\n"
      new(*args)
    end

    def comment(*args, &block)
      args.push block if block
      args.push GAP if args.empty?
      args.unshift "<!-- "
      args.push " -->\n"
      new(*args)
    end

    def comments(*args, &block)
      args.push block if block
      args.push GAP if args.empty?
      args.push "\n"
      comment("\n", *args)
    end
  end
end
