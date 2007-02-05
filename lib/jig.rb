
require 'strscan'
require 'set'

=begin rdoc
A jig is an ordered sequence of strings, lambdas, and gaps.  The
#to_s method creates a new string from this sequence as follows:
- strings are output as-is
- gaps are output as the empty string
- lambdas are evaluated and the results converted to a string

Gaps within a jig are not positional but instead are named.
The basic plug operation constructs a new jig with the named
gap(s) replaced with any of: a string, a jig, a lambda, or
any object that responds to #to_s.  For example:

			j = Jig.new("before", :alpha, "after")

This is a jig with a single gap named "alpha". Symbols are
used to represent and name gaps.

			j.plug(:alpha, "during")		# -> beforeduringafter

This operation doesn't change j.  It can be used again:

			j.plug(:alpha, "and")				# -> beforeandafter

There is a destructive version of plug that modifies
the jig in place:

			j.plug!(:alpha, "filled")		# -> beforefilledafter

There are a number of ways to construct a Jig and many of
them insert an implicit gap into the Jig.  This gap is
identified as Jig::GAP and is used as the default gap
for plug operations when one isn't provided:

	Jig.new("A", Jig::GAP, "C").plug("B")		# -> ABC

In order to make Jig's more useful for HTML generation,
the Jig class supports a variety of convenience methods;

	b = Jig.element("body")			# <body>GAP</body>
	b.plug("text")							# <body>text</body>

Method missing makes this even simpler:

	b = Jig.body
	b.plug("text")

Attributes can be specified with a hash:

	b = Jig.p({:class => "summary"})
	b.plug("This is a summary")
	# <p class="summary">This is a summary</p>

=end
class Jig
	VERSION = '0.8.0'
	GapPattern = "[a-zA-Z_/][a-zA-Z0-9_/]*"

	class Gap
		DefaultName = :__gap
		Identity = lambda { |*filling| return *filling }
		attr :name
		attr :fn
		def initialize(name=DefaultName, &fn)
			@name = name.to_sym
			@fn = fn || Identity
		end
		def inspect
			"[#{name}, #{fn.inspect}]"
		end
		def fill(filling)
			fn[filling]
		end
		def ==(other)
			eql?(other)
		end
		def eql?(other)
			name == other.name && fn == other.fn
		end
		def identity?
			@fn == Identity
		end
	end

	GAP = Gap::DefaultName
	Dgap = Gap.new

	attr_accessor :contents
	attr          :gaps
	attr					:eid
	attr					:css
	attr_accessor	:source

	def inspect
		info = gaps.map {|g| g.identity? && g.name || "#{g.name}{}" }
		contents.zip(info).flatten.inspect
	end

	# _full?_ returns _true_ if the jig has no remaining gaps to be filled and
	# _false_ otherwise.
	def full?
		gaps.empty?
	end

	# _null?_ returns _true_ if the jig has no gaps and no contents.
	def null?
		full? && to_s.empty?
	end

	# _gap_count_ returns the number of remaining gaps in the jig.
	def gap_count
		gaps.size
	end

	# _gap_set_ returns a Set containing the names of all remaining gaps.
	def gap_set
		gaps.inject(Set.new) { |s, gitem| s << gitem.name}
	end

	# _gap_list_ returns an Array containing the names of all remaining gaps.
	# A name may occur more than once in the list.
	def gap_list
		gaps.collect { |g| g.name }
	end

	# _has_gap?_ returns _true_ if the named gap exists in the jig, _false_ otherwise.
	def has_gap?(gname)
		gaps.find {|x| x.name == gname }
	end

	alias [] :has_gap?

	class <<self
		alias [] :new

		def configure(&block)
			new(class_eval(&block))
		end

		# Construct a null jig.  An null jig has no contents and no gaps and
		# is often useful as a starting point for construction more complex jigs
		def null
			new(nil)
		end
	end

	# A new jig is constructed from the list of _items_.  Simple gaps are indicated by
	# symbols.
	#   report = Jig.new('Report Generated at', :time)
	#   title = Jig.title(:title)
	# If a block is provided, it is appended as a proc to the list of items. The block is not
	# evaluated until the Jig is converted to a string by Jig#to_s.
	#   Jig.new("page created at: ") { Time.now }
	# If no arguments are given and no block is specified, the new jig will be constructed
	# with a single gap with the default gap name _Jig::DefaultGap_.
	#   one_gap = Jig.new
	#   filled = Jig.plug 'filling'  # default gap is used
	def initialize(*items, &block)
		@contents = [[]]
		@gaps = []
		@eid = nil
		if items.empty? && !block
			append_gap!(Dgap)
		else
			append!(*items)
			append!(block) if block
		end
	end

	# _freeze_ applies Kernel#freeze to the jig and its internal structures.  A frozen jig
	# may still be used with non-mutating methods such as #append or #plug but an exception
	# will be raised if a mutating method such as #append! or #plug! are used.
	def freeze
		super
		@contents.freeze
		@gaps.freeze
		@eid.freeze
	end

	# Two jigs are considered equal by _==_ if their gap structure is the same and
	# their contents, when flattened, are also the same. Procs are not evaluated.
	def ==(other)
		(gaps == other.gaps) && (contents.flatten == other.contents.flatten)
	end

	# If jig.to_s equals other.to_s, return _true_, otherwise _false.
	# Procs that are part of the jig will be evaluated
	def =~(other)
		to_s == other.to_s
	end

	def to_jig
		self
	end

	def +(other)
		Jig.new(self, other)
	end

	def *(other)
		case other
		when Fixnum
			(1..other).inject(Jig.null)  { |j,i| j.append_jig!(self) }
		when Array
			other.inject(Jig.null) { |j,x| j.append!( plug(GAP, x) ) }
		else
			raise ArgumentError, "other operand for * must be Fixnum or Array, was #{other.class})"
		end
	end

	# Create a new jig formed by inserting a copy of the current jig between each
	# element of the array.  The elements of the array are treated like plug arguments.
	# Example : (Jig.new('X') | [1,2,3]).to_s   # =>  "1X2X3"
	# XXX
	def wedge(array)
		Jig[array.zip((1..(array.size - 1)).to_a.map { self.dup })]
	end

	def eid=(eid)
		raise RuntimeError, "no eid reassignment permitted" if @eid
		@eid = eid 
	end

	def gaps=(other)
		@gaps = other
	end
	protected :gaps=

	def dup
		other = super
		other.contents = @contents.dup
		other.gaps = @gaps.dup
		other
	end

	def append!(*items)
		items.each do |i|
			case i
			when String 	then contents.last << i
			when Symbol 	then append_gap! Gap.new(i)
			when Jig::Gap then append_gap! i
			when Hash 		then append!(*i.map { |k,v| to_attr(k, v) })
			when Jig 			then append_jig! i
			else 
				if i.respond_to? :to_jig
					append_jig! i.to_jig
				else
					if i.respond_to? :call
						def i.to_s
							call.to_s
						end
						def i.inspect
							%Q{<Proc:0x#{"%6x" % object_id}>}
						end
					end
					contents.last << i
				end
			end
		end
		self
	end

	def coerce_item(item)
		case item
		when String 	then item
		when Symbol 	then Gap.new(item)
		when Jig::Gap then item
		when Hash 		then item.map { |k,v| to_attr(k, v) }
		when Jig 			then item
		else 
			if item.respond_to? :to_jig
				item.to_jig
			else
				if item.respond_to? :call
					def item.to_s
						call.to_s
					end
					def item.inspect
						%Q{<Proc:0x#{"%6x" % object_id}>}
					end
				end
				item
			end
		end
	end

	def append(*items)
		dup.append!(*items)
	end

	def to_attr(aname, value)
		if Symbol === value
			Gap.new(value) { |fill| aplug(aname, fill) }
		elsif Gap === value
			value
		else
			aplug(aname, value)
		end
	end

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

	def append_gap!(gitem)
		@gaps << gitem
		@contents << []
		self
	end

	def append_jig!(other)
		self.contents = contents[0..-2] + [contents[-1] + other.contents[0]] + other.contents[1..-1]
		gaps.concat other.gaps
		self
	end

	def <<(arg)
		if Hash === arg
			plug!(arg)
		else
			plug!(GAP, arg)
		end
	end

	def plug(*args, &block)
		dup.plug!(*args, &block)
	end

	def before(gap, item=nil)
		gap,item = Jig::GAP, gap unless item
		plug(gap, Jig.new(item, gap))
	end

	def after(gap, item=nil)
		gap,item = Jig::GAP, gap unless item
		plug(gap, Jig.new(gap, item))
	end

	def plug!(first, *more, &block)
		case first
		when Symbol 
			gap = first
		when Hash 
			return fill(first)
		else
			more.unshift first
			gap = GAP
		end
		return self unless has_gap?(gap)
		more.push(block) if block
		_plug!(gap, *more)
	end

	def _plug!(gname, item, *more)
		added = 0
		self.gaps = gaps.inject([]) do |list, gap|
			next list << gap unless gap.name == gname
			match = list.size
			fill = gap.fill(item, *more)
			fill = fill.to_jig if fill.respond_to? :to_jig
			if Jig === fill
			  case fill.gaps.size
		    when 0
		      contents[match,2] = [[contents[match], fill.contents.first, contents[match+1]]]
	      when 1
	        contents[match,2] = [[ contents[match], fill.contents.first ], [fill.contents.last, contents[match+1]]]
				else
				  contents[match,2] = [[contents[match], fill.contents.first ], fill.contents[1..-2], [fill.contents.last, contents[match+1]]]
			  end
			  #plug_pos(match, fill)
				list.push(*fill.gaps)
			elsif Symbol === fill
			  list.push Gap.new(fill)
			elsif Gap === fill
				list.push fill
			else
				contents[match, 2] = [contents[match,2].insert(1, fill)]
				list
			end
		end
		self
	end

	def fill(hash)
		dup.fill!(hash)
	end

	def fill!(filling)
		return plug!(filling) unless filling.respond_to? :has_key?
		gap_set.inject(self) {|jig,gap|
			jig.plug!(gap, filling[gap]) if filling.has_key?(gap)
			jig
		}
	rescue
		puts "hash was: #{filling.inspect}"
		raise
	end

	def plug_all(hash)
		dup.plug_all!(hash)
	end

	def plug_all!(hash)
		gap_set.inject(self) {|jig,gap| jig.plug!(gap, hash[gap]) }
		#gaps.inject(self) {|jig,gap| jig.plug!(gap.name, hash[gap.name])}
	end

	def close
		gap_set.inject(self) {|jig, gap| jig.plug(gap, nil) }
	end

	def to_s
		contents.to_s
	end

	Base = Hash.new { |h,k| h[k] = element(k).freeze }
	Null = begin
		n = null
		n.freeze
		n
	end

	class <<self
		GapStart = '(a:|:|\{)'
		GapEnd = '(:a|:|\})'
		DelimStart = "(<#{GapStart})"
		DelimEnd = "(#{GapEnd}>)"


		def parse(string=nil, context=nil, &block)
			if block
				context = block
				string = block.call
			end
			raw = StringScanner.new(string)
			items = []
			while !raw.eos?
				if chunk = raw.scan_until(Regexp.new("#{DelimStart}"))
					items << chunk[0..-3] unless chunk[0..-3].empty?
					start_delim = raw[1]
				else
					items << raw.rest
					break
				end

				case start_delim
				when '<:'		# gap
					unless raw.scan(Regexp.new("(#{GapPattern}),(#{GapPattern})(#{DelimEnd})"))
						unless raw.scan(Regexp.new("((#{GapPattern})|)#{DelimEnd}"))
							raise ArgumentError, "invalid gap found: #{raw.rest[0..10]}.."
						end
						if raw[1].empty?
							items << GAP
						else
							items << raw[2].to_sym
						end
						unless (end_delim = raw[3]) == ':>'
							raise ArgumentError, "mismatched delimiters: '#{start_delim}' and '#{end_delim}'"
						end
					else
						if items[-1].respond_to?(:merge)
							items[-1].merge! raw[1] => raw[2].to_sym
						else
							items << { raw[1] => raw[2].to_sym }
						end
						unless (end_delim = raw[3]) == ':>'
							raise ArgumentError, "mismatched delimiters: '#{start_delim}' and '#{end_delim}'"
						end
					end
				when '<{'		# code gap
					unless raw.scan(Regexp.new("(.*)#{DelimEnd}"))
						raise ArgumentError, "unterminated code gap found: #{raw.rest[0..10]}.."
					end
					code = raw[1]
					unless (end_delim = raw[2]) == '}>'
						raise ArgumentError, "mismatched delimiters: '#{start_delim}' and '#{end_delim}'"
					end
					items << eval( "lambda { #{code} }", context)
				end
			end
			newjig = self[*items]
			newjig.source = string
			newjig
		end

		def parse_file(filename)
			parse(File.read(filename))
		end

		def container(tag, css, *args, &block)
			@css = css
			element_with_id(tag, {:class => @css}, *args, &block)
		end

		def divc(css_class, *args, &block)
			container(:div, css_class, *args, &block)
		end

		def element(name='div', *args, &block)
			attrs = args.shift if Hash === args.first

			items = ["</#{name}>\n"]
			items[0,0] = block if block
			items[0,0] = args unless args.empty?
			items[0,0] = GAP unless items.size > 3
			items[0,0] = attrs && ["<#{name}", attrs, ">"]  || "<#{name}>"
			new(*items)
		end

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

		def method_missing(symbol, *args, &block)
			text = symbol.to_s
			if text =~ /_with_id$/
				element_with_id(text.sub(/_with_id$/,'').to_sym, *args, &block)
			elsif text =~ /_$/
				element(text.chop, *args, &block)
			else
				element(symbol, *args, &block)
			end
		end
	end
end
