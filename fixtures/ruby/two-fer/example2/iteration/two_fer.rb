class TwoFer
  def self.two_fer(name)
    name = "you" if name.nil?
    "One for #{name}, one for me."
  end
end
