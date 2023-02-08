class String
  def pattern_match?(search)
    pos = index('*')

    if pos.nil?
      search == self
    else
      search.index(self[0, pos]).present?
    end
  end
end
