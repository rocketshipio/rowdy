# frozen_string_literal: true

require_relative "rowdy/version"

module Rowdy
  class Error < StandardError; end

  module Routing
    def call(env)
      dispatch Transaction.from_rack env
    end

    protected

    def dispatch(http)
      route http
      http.response.to_a
    end
  end

  class Transaction
    Request = Class.new(Rack::Request)
    Response = Class.new(Rack::Response)

    class Route
      def initialize(transaction)
        @request = transaction.request
      end

      def request_method
        @request.request_method.downcase.to_sym
      end

      def path_segments
        @request.path.split("/")[1..-1]
      end

      def domain_segments
        @request.host.split(".")
      end

      def is_root?
        @request.path == "/"
      end

      def deconstruct
        path_segments
      end

      def deconstruct_keys(keys)
        {
          fullpath: @request.path,
          path: path_segments,
          host: @request.host,
          domain: domain_segments,
          scheme: @request.scheme,
          port: @request.port,
          params: @request.params,
          method: request_method,
          ip: @request.ip,
          root: is_root?
        }
      end
    end

    attr_reader :request, :response

    def initialize(request:, response:)
      @request = request
      @response = response
    end

    def route
      @route ||= Route.new(self)
    end

    def self.from_rack(env)
      new request: Request.new(env), response: Response.new
    end
  end

  class Server
    include Routing
  end

  # Calls the `get`, `post`, etc. method on the class.
  class Action
    include Routing

    def route(http)
      http.response.write self.public_send http.route.request_method
    end
  end

  module Controller
    class Resource
      include Routing

      class Base < Action
        def initialize(model:)
          @model = model
        end
      end

      class Show < Base
        def get
          @model
        end
      end

      class Edit < Base
        def get
          "Editing #{@model}"
        end
      end

      def initialize(scope:, id:)
        @scope = scope
        @id = id
        @model = @scope.find(@id)
      end

      def show
        self.class::Show.new(model: @model)
      end

      def edit
        self.class::Edit.new(model: @model)
      end

      def destroy
        @model.destroy
      end

      def route(http)
        case http.route
          in path: [ _, id ], method: :get
            show.route http
          in path: [ _, id, "edit" ], method: :get
            edit.route http
          in path: [ _, id ], method: :delete
            destroy
        end
      end
    end

    class Resources
      include Routing

      class Base < Action
        def initialize(scope:)
          @scope = scope
        end
      end

      class Index < Base
        def get
          @scope.all
        end
      end

      def initialize(scope:, path:)
        @scope = scope
        @path = path
      end

      def index
        Index.new(scope: @scope)
      end

      def resource(id)
        resource_class.new(scope: @scope, id: id)
      end

      def resource_class
        Resource
      end

      def route(http)
        case http.route
          in path: [ ^@path ], method: :get
            index.route http
          in path: [ ^@path, id, *_ ]
            resource(id).route http
        end
      end
    end
  end
end
