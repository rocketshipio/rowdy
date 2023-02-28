require "bundler/inline"
require "json"

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

module Authentication
  def route(http)
    auth = Rack::Auth::Basic::Request.new(http.request.env)
    if auth.provided?
      # super http.define :user do
      #   auth.username
      # end
      super http
    else
      http.response['WWW-Authenticate'] = %(Basic realm="Super duper ultra-secret area")
      http.response.write "Authenticate with any username and password"
      http.response.status = 401
    end
  end
end

class ProtectedResources < Rowdy::Controller::Resources
  prepend Authentication

  class Resource < Resource
    def show(http)
      case http.format
        in html:
          html << """
            <h1>#{@model.name}</h1>
            <p>#{@model.email}</p>
          """
        in json:
          json << @model.to_h.to_json
        in plain:
          plain << @model.inspect
      end
    end

    def destroy(http)
      @model.destroy
    end
  end
end

# Application code (dev sees this)
class Application < Rowdy::Server
  class Transaction < Transaction
    def user
      auth = Rack::Auth::Basic::Request.new(request.env)
      if auth.provided?
        auth.username
      else
        http.response['WWW-Authenticate'] = %(Basic realm="Super duper ultra-secret area")
        http.response.write "Authenticate with any username and password"
        http.response.status = 401
      end
    end
  end

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