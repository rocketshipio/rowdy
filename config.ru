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

class ProtectedResources < Rowdy::Controller::Resources
  class Resource < Resource
    def show
      "Super secret model #{@model.inspect}"
    end
  end

  def route(http)
    authenticate http do
      super http
    end
  end

  private

  def authenticate(http)
    if Rack::Auth::Basic::Request.new(http.request.env).provided?
      yield
    else
      http.response['WWW-Authenticate'] = %(Basic realm="Super duper ultra-secret area")
      http.response.write "Authenticate with any username and password"
      http.response.status = 401
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
      in "folks", *_
        ProtectedResources.new(scope: Model::Person).route(http)
    else
      http.response.write "Not Found"
      http.response.status = 404
    end
  end
end

run Application.new