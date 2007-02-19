
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
  j = Jig.new(:alpha)
The plug operation derives a new jig from the old jig.
  j.plug(:alpha, "during")        # -> beforeduringafter

This operation doesn't change j.  It can be used again:

  j.plug(:alpha, "and")           # -> beforeandafter

There is a destructive version of plug that modifies
the jig in place:

  j.plug!(:alpha, "filled")       # -> beforefilledafter

There are a number of ways to construct a Jig and many of
them insert an implicit gap into the Jig.  This gap is
identified as :___ and is used as the default gap
for plug operations when one isn't provided:

	Jig.new("A", :___, "C").plug("B")		# -> ABC

In order to make Jig's more useful for HTML generation,
the Jig class supports a variety of convenience methods;

	b = Jig.element("body")			# <body></body>
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
		DefaultName = :___
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
			"#<Gap: [#{name}, #{fn.inspect}]>"
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

	attr_accessor  :contents    # the sequence of objects
	attr           :gaps        # the unfilled gaps
	attr	         :extra       # extra state information, used by extensions
	attr_accessor	 :source
	protected :contents=

	# A jig is rendered as an array of objects with gaps represented by symbols.
	# Gaps with associated filter functions are shown with trailing braces: :gap{}
	def inspect
		info = gaps.map {|g| g.identity? && g.name || "#{g.name}{}" }
		"#<Jig: #{contents.zip(info).flatten[0..-2].inspect}>"
	end

	# Return _true_ if the jig has no remaining gaps to be filled and
	# _false_ otherwise.
	def full?
		gaps.empty?
	end

	# _null?_ returns _true_ if the jig has no gaps and no contents.
	def null?
		full? && to_s.empty?
	end

	def empty?
	  null? || to_s.empty?
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
	def []=(gap, obj)
		plug!(gap, obj)
	end

	class <<self
		alias [] :new

		# Construct a null jig.  An null jig has no contents and no gaps and
		# is often useful as a starting point for construction of more complex jigs.
		# It can be considered analogous to an empty array or a null string.
		def null
			new(nil)
		end
	end

	# Construct A new jig from the list of _items_.  Symbols in the list are
	# replaced with a gap using the symbol as the name of the gap.
	#   report = Jig.new('Report Generated at', :time)
	#   title = Jig.title(:title)
	# If a block is provided, it is appended as a proc to the list of items. The block is not
	# evaluated until the Jig is converted to a string by Jig#to_s.
	#   Jig.new("page created at: ") { Time.now }
	# If no arguments are given and no block is specified, the new jig will be constructed
	# with a single gap with the default gap name Jig::GAP
	#   one_gap = Jig.new
	#   filled = Jig.plug 'filling'  # default gap is used
	def initialize(*items, &block)
		@contents = [[]]
		@gaps = []
		@extra = {}
		if items.empty? && !block
			push_gap(Dgap)
		else
			push(*items)
			push(block) if block
		end
	end

	# _freeze_ applies Kernel#freeze to the jig and its internal structures.  A frozen jig
	# may still be used with non-mutating methods such as #concat or #plug but an exception
	# will be raised if a mutating method such as #concat or #plug! are used.
	def freeze
		super
		@contents.freeze
		@gaps.freeze
		@extra.freeze
		self
	end

	# Two jigs are considered equal by _==_ if their gap structure is the same and
	# their contents, when flattened, are also the same. Procs are not evaluated.
	def ==(other)
		(gaps == other.gaps) && (contents.flatten == other.contents.flatten)
	end

	# If jig.to_s equals other.to_s, return _true_, otherwise _false.
	# Procs that are part of the jig will be evaluated.
	def =~(other)
		to_s == other.to_s
	end

	# Return self.  Useful when trying to coerce objects to jigs.
	def to_jig
		self
	end

	# call-seq:
	#   jig + obj       -> a_jig
	# Construct a new jig by pushing _obj_ onto a duplicate of _jig_.
	def +(other)
		dup.push(other)
	end

	# call-seq:
	#   jig * int    -> a_jig
	#   jig * array  -> a_jig
	#
	# With an integer argument, a new jig is constructed by concatenating
	# *int* copies of *self*.
	#   three = Jig.new * 3
	#   three.plug '3'    # "333"
	# With an array argument, the elements of the array are used to plug
	# the default gap of the current jig.  The resulting jigs are concatenated
	# to form the final result:
	#   item = Jig.new("- ", :___, "\n") 
	#   list = item * [1,2,3]
	#   puts list
	#   - 1
	#   - 2
	#   - 3
	def *(other)
		case other
		when Integer
			(1..other).inject(Jig.null)  { |j,i| j.push_jig(self) }
		when Array
			other.inject(Jig.null) { |j,x| j.concat( plug(x) ) }
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

	# Replace current set of gaps with _other_
	def gaps=(other)
		@gaps = other
	end
	protected :gaps=

	# A duplicate jig is returned.  This is a shallow copy, the 
	# contents of the jig are not duplicated.
	def dup
		other = super
		other.contents = @contents.dup
		other.gaps = @gaps.dup
		other
	end

	# Adds the items to the current contents of 
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
	def push(*items)
		items.each do |i|
			case i
			when Symbol 	then push_gap Gap.new(i)
			when String 	then contents.last << i
			when Jig::Gap then push_gap i
			when Jig 			then push_jig i
			else 
				if respond_to?(p = "push_#{i.class.name.downcase}")
					send(p, i)
				elsif i.respond_to? :to_jig
					push_jig i.to_jig
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

	def concat(item)
		push(*item)
	end

	# The current jig is modified by replacing a gap with other items.
	def plug!(first, *more, &block)
		case first
		when Symbol 
			if more.empty?
				more.unshift first
				gap = :___
			else
				gap = first
			end
		when Hash 
			return fill(first)
		else
			more.unshift first
			gap = :___
		end
		return self unless has_gap?(gap)
		more.push(block) if block
		_plug!(gap, *more)
	end

	# The current jig is duplicated and the result is modified as with #plug!
	def plug(*args, &block)
		dup.plug!(*args, &block)
	end

	alias merge :plug
	alias merge! :plug!

	# A new jig is constructed by inserting the item *before* the specified gap.
	# The gap itself remains in the new jig.
	def before(gap, item=nil)
		gap,item = :___, gap unless item
		plug(gap, Jig.new(item, gap))
	end

	# A new jig is constructed by inserting the item *after* the specified gap.
	# The gap itself remains in the new jig.
	def after(gap, item=nil)
		gap,item = :___, gap unless item
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

	# This method is where the magic happens. The contents and gap arrays
	# are modified such that the named gap is removed and the items are 
	# put in its place.
	#
	# Gaps and contents are maintainted in two separate arrays.  Each
	# element in the contents array is a tree of objects implemented as
	# nested arrays.  The first element of the gap array represents the
	# gap between the the first and second element of the contents array.
	#
	#             0   1   2   3
	# contents:   c1  c2  c3  c4
	# gaps:       g1  g2  g3
	#
	# sequence:   c1  g1  c2  g2  c3  g3 c4
	#
	# The following relation always holds:  gaps.size + 1 == contents.size
	def _plug!(gname, *items)
		self.gaps = gaps.inject([]) do |list, gap|
			next list << gap unless gap.name == gname
			match = list.size
			fill = gap.fill(*items)
			fill = fill.to_jig if fill.respond_to? :to_jig
			if Jig === fill
			  case fill.gaps.size
		    when 0
		      contents[match,2] = [[contents[match], fill.contents.first, contents[match+1]]]
	      when 1
	        contents[match,2] = [[contents[match], fill.contents.first ], [fill.contents.last, contents[match+1]]]
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

	def push_gap(gitem)
		@gaps << gitem
		@contents << []
		self
	end

	def push_jig(other)
		self.contents = contents[0..-2] + [contents[-1] + other.contents[0]] + other.contents[1..-1]
		gaps.concat other.gaps
		self
	end
	protected :push_jig

	Null = null.freeze

	class <<self
		GapStart = '(a:|:|\{)'
		GapEnd = '(:a|:|\})'
		DelimStart = Regexp.new "(<#{GapStart})"
		DelimEnd = "(#{GapEnd}>)"

		# Convert a string into a jig. Code in the string is evaluated relative to _context_,
		# which should be an instance of Binding.  If a block is provided, the block is evaluated
		# and its result is parsed into a jig.  In this case, the block is used as the
		# context for evaluating any embedded code.
		#
		# The method parses the string by looking for the following sequences:
		#   <:identifier:>		is converted into a named gap
		#   <:identifier,identifier:>  is converted to a key/value pair and becomes an attribute gap
		#   <{code}>          is converted to a proc
		def parse(string=nil, context=nil, &block)
			require 'jig/html'
			if block
				context = block
				string = block.call
			end
			raw = StringScanner.new(string)
			items = []
			while !raw.eos?
				if chunk = raw.scan_until(DelimStart)
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
							items << :___
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

		# Read the contents of filename into a string and parse it as Jig.
		def parse_file(filename, *context)
			parse(File.read(filename), *context)
		end

		# Incorporate methods and class methods specific to _feature_.
		#
		def enable(feature)
			if f = %w{xml}.find {|x| x == feature.to_s }
				require "jig/#{f.capitalize}"
				extend Jig.const_get(f.capitalize)::ClassMethods
				include Jig::const_get(f.capitalize)
			end
			f
		end
	end
end
