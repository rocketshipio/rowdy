require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "rowdy", path: "."
  gem "rack"
  gem "puma"
end

module Model
  class Person < Data.define(:name, :email)
    def self.all
      10.times.map { |n| find n }
    end

    def self.find(id)
      new name: "Person #{id}", email: "person-#{id}@example.com"
    end
  end
end

# Application code (dev sees this)
class Application < Rowdy::Server
  def route(http)
    http.response.headers["Content-Type"] = "text/plain"
    http.response.status = 200

    case http.route
      in root: true
        http.response.write "Hello world! Check out the resources over at /people."
      in "people", *_
        Rowdy::Controller::Resources.new(scope: Model::Person).route(http)
    else
      http.response.write "Not Found"
      http.response.status = 404
    end
  end
end

run Application.new