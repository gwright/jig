
require 'strscan'
require 'set'

=begin rdoc
A jig is an ordered sequence of objects and named gaps. During construction,
a gap is represented by a symbol:

  Jig.new('left', :middle, 'right')   # ["left", :middle, "right"]
  Jig.new(1, :two, 3.0, "4")          # [1, :two, 3.0, "4"]
  Jig.new(lambda { rand(6) })         # [<Proc:0x 255b2>]

As a convenience, a block provided to Jig::new is added to the sequence as a proc:

  Jig.new { rand(6) }                 # [<Proc:0x 27646>]

Jig#[] also constructs new jig instances:

  Jig[:header, :body, :footer]        # [:header, :body, :footer]

The primary motivation for Jigs is to provide a templating mechanism for strings.
In woodworking, a jig is a piece of wood used as a template or guide for other tools.

At any time, a jig can be converted to a string by Jig#to_s.  The string is 
constructed by concatenating string representations of the objects in the jig as follows:
- strings are concatenated as-is
- gaps are skipped
- procs are evaluated, the results converted to a string, and concatenated
- other objects are converted by calling _to_s_ and the resulting string is concatenated

A variety of operations are provided to manipulate jigs but the
most interesting is the 'plug' operation:

  grep  = Jig.new("grep", :pattern, :files)
  grep_religion = command.plug(:pattern, "religion")
  grep_all = grep_religion.plug(:files, %w{file1 file2 file3}.join)

which constructs a new jig that shares all the contents of the
previous jig but with the named gap replaced by one or more objects.
If there are more than one gaps with the same name, they are all
replaced with the same sequence of objects.

			j = Jig.new("first", :separator, "middle", :separator, "after")
			j.plug(:separator, '/').to_s    # "first/middle/last"

This is a jig with a single gap named "alpha".

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

	# A Gap represents a named position within the ordered sequence of objects
	# stored in a Jig.  In addition to a name, a gap can also have an associated
	# lambda.  When a gap is filled by a plug operation, the replacement items are
	# passed to the lambda and the return value(s) are used as the replacement items.
	# The default lambda simply returns the same list of items.
	class Gap
		DefaultName = :__gap
		Identity = lambda { |*filling| return *filling }
		attr :name		# the name associated with the gap
		attr :fn			# the lambda associated with the gap

		# Construct a new gap with the specified name.  A block, if given is used
		# as the filter for replacement items.
		def initialize(name=DefaultName, &fn)
			@name = name.to_sym
			@fn = fn && lambda(&fn) || Identity
		end

		def inspect
			"[#{name}, #{fn.inspect}]"
		end

		# Pass the replacement items through the filter
		def fill(*filling)
			fn[*filling]
		end

		# Two gaps are equal if they have the same name and
		# use the same filter function.
		def ==(other)
			name == other.name && fn == other.fn
		end
		# Return _true_ if the filter function is the default identity filter.
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
		contents.zip(info).flatten[0..-2].inspect
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

	# Return self.  Useful when trying to coerce objects to jigs.
	def to_jig
		self
	end

	# Construct a new jig by appending the current jig with _other_.
	def +(other)
		Jig.new(self, other)
	end

	# When _other_ is an Integer, a new jig is constructed by concatenating
	# the current jig the specified number of times:
	#   three = Jig.new * 3
	#   three.plug '3'    # "333"
	# when _other_ is an Array, the elements of the array are used to plug
	# the default gap of the current jig.  The resulting jigs are concatenated
	# to form the final result:
	#   list_item = Jig.new("- ", GAP, "\n") 
	#   list = list_item * [1,2,3]
	#   puts list
	#   - 1
	#   - 2
	#   - 3
	def *(other)
		case other
		when Integer
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

	# This method is used to simplify construction of new jigs.
	def gaps=(other)
		@gaps = other
	end
	protected :gaps=

	# A duplicate jig is returned.  The contents of the current jig and the
	# new jig are shared.
	def dup
		other = super
		other.contents = @contents.dup
		other.gaps = @gaps.dup
		other
	end

	# Mutates the current jig by appending the items as follows:
	# - strings are appended as is
	# - symbols are converted to gaps and appended 
	# - instances of Jig::Gap are appended as is
	# - jigs: each item of the other jig is appended in order to the current jig
	# - hash: each key, value pair is appended as follows:
	#   - if the value is a symbol, the pair is appended as an attribute gap
	#   - if the value is a Jig::Gap, the pair is appended as an attribute gap
	#   - otherwise the pair is converted to a string (#{key}=\"#{value}\") and appended
	# - any object that responds to _to_jig_ is converted and appended
	# - any object that responds to _call_ is appended as a proc
	# - all other objects are appended as is.
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
						(class <<i; self; end).class_eval {
							alias __to_s :to_s
							alias inspect :__to_s
							def to_s; call.to_s; end
						}
					end
					contents.last << i
				end
			end
		end
		self
	end

	# XXX can this be removed??
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

	# The current jig is duplicated and then mutated by appended the items to the new jig.
	def append(*items)
		dup.append!(*items)
	end

	# The current jig is modified by replacing a gap with other items.
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

	# The current jig is duplicated and the result is modified as with #plug!
	def plug(*args, &block)
		dup.plug!(*args, &block)
	end

	# A new jig is constructed by inserting the item *before* the specified gap.
	# The gap itself remains in the new jig.
	def before(gap, item=nil)
		gap,item = Jig::GAP, gap unless item
		plug(gap, Jig.new(item, gap))
	end

	# A new jig is constructed by inserting the item *after* the specified gap.
	# The gap itself remains in the new jig.
	def after(gap, item=nil)
		gap,item = Jig::GAP, gap unless item
		plug(gap, Jig.new(gap, item))
	end

	alias << :plug!

	# Duplicate the current jig and then fill any gaps as with _fill!_
	def fill(hash)
		dup.fill!(hash)
	end

	# Mutate the existing jig by filling all remaining gaps.  The gap name
	# is looked up via _pairs[name]_ and the result is used to plug the gap.
	# If there is no match in _pairs_ for a gap, it remains unplugged.
	# This method is useful when the number of gaps is small compared to
	# the number of pairs.
	def fill!(pairs)
		return plug!(pairs) unless pairs.respond_to? :has_key?
		gap_set.inject(self) {|jig,gap|
			jig.plug!(gap, pairs[gap]) if pairs.has_key?(gap)
			jig
		}
	rescue
		puts "hash was: #{pairs.inspect}"
		raise
	end

	# Duplicate the current jig and then fill any gaps specified by pairs via
	# _plug_all!_.
	def plug_all(pairs)
		dup.plug_all!(pairs)
	end

	# Fill all remaining gaps with plugs from pairs. It is assumed that pairs
	# will always return a value for any key, perhaps nil.
	def plug_all!(pairs={})
		gap_set.inject(self) {|jig,gap| jig.plug!(gap, pairs[gap]) }
	end

	alias close :plug_all!

	# A string is constructed by concatenating the contents of the jig.
	# Gaps are effectively considered null strings.  Any procs in the jig
	# are evaluated, the results converted to a string via to_s.  All
	# other objects are converted to strings via to_s.
	def to_s
		contents.join
	end

	private 

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

	# If value is not true, return null string.
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
	protected :append_jig!


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

	end
end
