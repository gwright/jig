
module Asserts
  def assert_as_string(expected, jig, message='')
    case expected
    when String
      assert_equal(expected, jig.to_s, message)
    when Regexp
      assert_match(expected, jig.to_s, message)
    end
  end
	def assert_not_similar(a, b, mess="")
		assert_not_match(a, b, mess)
  end
end
