require_relative "lib/rowdy.rb"

class Application
  include Rowdy::Routing

  get def hello(subject: "World") = "Hello #{subject}"
  get def add(a: 0, b: 0) = "#{a} + #{b} = #{Integer(a) + Integer(b)}"
end

run Application.new