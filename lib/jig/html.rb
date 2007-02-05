require 'jig'

class Jig
	Encode = Hash[*%w{& amp " quot > gt < lt}]

	def self.escape(target)
		unless Jig === target 
			target = Jig.new(target.to_s.gsub(/[#{Encode.keys.join}]/) {|m| "&#{Encode[m]};" })
		end
		target
	end
end
