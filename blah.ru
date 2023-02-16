# Library code (dev doesn't see this)
class Server
  class Transaction < Data.define(:request, :response)
    class Request < Rack::Request
      def request_method
        super.downcase.to_sym
      end

      def path_segments
        path.split("/")[1..-1]
      end

      def domain_segments
        host.split(".")
      end

      def deconstruct_keys(keys)
        {
          fullpath: path,
          path: path_segments,
          host: host,
          domain: domain_segments,
          scheme: scheme,
          port: port,
          params: params,
          method: request_method,
          ip: ip,
        }
      end
    end

    class Response < Rack::Response
    end

    def self.from_rack(env)
      new request: Request.new(env), response: Response.new
    end
  end

  def call(env)
    dispatch Transaction.from_rack env
  end

  protected

  def dispatch(http)
    route http
    http.response.to_a
  end
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

module Action
  class Base < Server
    def route(http)
      http.response.write self.public_send http.request.request_method
    end
  end

  class Singular < Base
    def initialize(model:)
      @model = model
    end
  end

  class Collection < Base
    def initialize(scope:)
      @scope = scope
    end
  end

  class Index < Collection
    def get
      @scope.all
    end
  end

  class Show < Singular
    def get
      @model
    end
  end

  class Edit < Singular
    def get
      "Editing #{@model}"
    end
  end
end

module Controller
  class Resource < Server
    def initialize(scope:, id:)
      @scope = scope
      @id = id
      @model = @scope.find(@id)
    end

    def show
      Action::Show.new(model: @model)
    end

    def edit
      Action::Edit.new(model: @model)
    end

    def destroy
      @model.destroy
    end

    def route(http)
      case http.request
        in path: [ _, id ], method: :get
          show.route http
        in path: [ _, id, "edit" ], method: :get
          edit.route http
        in path: [ _, id ], method: :delete
          destroy
      end
    end
  end

  class Resources < Server
    def initialize(scope:, path: "people")
      @scope = scope
      @path = path
    end

    def index
      Action::Index.new(scope: @scope)
    end

    def resource(id)
      Resource.new(scope: @scope, id: id)
    end

    def route(http)
      case http.request
        in path: [ ^@path ], method: :get
          index.route http
        in path: [ ^@path, id, *_ ]
          resource(id).route http
      end
    end
  end
end


# Application code (dev sees this)
class Application < Server
  def route(http)
    http.response.headers["Content-Type"] = "text/plain"

    case http.request
      in path: ["foo"]
        http.response.write "foo"
      in path: ["people", *_ ]
        Controller::Resources.new(scope: Model::Person).route(http)
    else
      http.response.write "Not Found"
      http.response.status = 404
    end
  end
end

run Application.new