
require 'jig'

class Jig
	module CSS
		# Element ID: 
		def push_hash(hash)
			push(*hash.map { |k,v| self.class.attribute(k, v) })
		end
		protected :push_hash

    def plist(plist)
      declarations = plist.map { |k,v| "#{k}: #{v}; " }.join
      before(:__p, declarations)
    end

    # Construct a selector with the current selector as the parent
    # and the other selector as the child.
    # 
    #   (div > p).to_s     # 'div > p {}'
    def >(other)
      before(:__s, ">", other.slice(0))
    end

    def +(other)
      before(:__s, "+", other.slice(0))
    end

    def *(other)
      before(:__s, "#", other.slice(0))
    end

    def %(other)
      before(:__s, ":", other.slice(0))
    end

    #def -@
    #  self.class.new("#", self)
    #end

    def >>(other)
      before(:__s, " ", other.slice(0))
    end

    def method_missing(sym)
      before(:__s, ".#{sym}")
    end

    def [](*args)
      if args.size == 1 && args.first.respond_to?(:to_hash) && args.first.size == 1
        k,v = *args.first.to_a.first
        case v
        when String
          before(:__s, %Q{[#{k}="#{v}"]})
        when Regexp
          if k.to_s == 'lang'
            before(:__s, %Q{[lang|="#{v}"]})
          else
            before(:__s, %Q{[#{k}~="#{v.to_s.split(':').last.chop}"]})
          end
        else
          self
        end
      elsif args.size == 1 && args.first.respond_to?(:to_s)
        before(:__s, "[#{args.first}]")
      else
        self
      end
    end

	end

  module CSS::ClassMethods
    Newlines = [:html, :head, :body, :title, :div, :p, :table, :script, :form]
		Encode = Hash[*%w{& amp " quot > gt < lt}]

    def rule(selector="", plist=nil)
      #base = (@_rule ||= new(:__s, " {\n  ", :__ps, :__p, "}\n").freeze)
      base = (@_rule ||= new(:__s, " {", :__ps, :__p, "}").freeze)
      declarations = plist && plist.map { |k,v| "#{k}: #{v}; " }.join
      base = base.before(:__s, selector) if selector
      base = base.before(:__p, declarations) if declarations
      base
    end

    # Generate a universal selector rule
    def us(*args)
      rule('*', *args)
    end

    def ___
      rule
    end

    def method_missing(sym, *args)
      rule(sym.to_s, *args)
    end

  end
end
