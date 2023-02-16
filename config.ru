require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "rowdy", path: "."
  gem "phlex"
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

module Controller
  class Resource < Rowdy::Controller::Resource
    class Show < Rowdy::Controller::Resource::Show
      class View < Phlex::HTML
        def initialize(model:)
          @model = model
        end

        def template(&)
          html do
            head do
              title { @title }
            end

            body do
              h1 { @model.name }
              pre do
                code { @model.inspect }
              end
            end
          end
        end
      end

      def route(http)
        http.response.headers["Content-Type"] = "text/html"
        super http
      end

      def get
        View.new(model: @model).call
      end
    end
  end

  class Resources < Rowdy::Controller::Resources
    def resource_class = Resource
  end
end

# Application code (dev sees this)
class Application < Rowdy::Server
  def route(http)
    http.response.headers["Content-Type"] = "text/plain"
    http.response.status = 200

    case http.route
      in root: true
        http.response.write "Hello world!"
      in "people", *_
        Controller::Resources.new(scope: Model::Person, path: "people").route(http)
    else
      http.response.write "Not Found"
      http.response.status = 404
    end
  end
end

run Application.new