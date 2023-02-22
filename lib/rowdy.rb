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

  module Controller
    class Resource
      include Routing

      def initialize(model:)
        @model = model
      end

      def show
        "Showing #{@model.inspect}"
      end

      def edit
        "Editing #{@model.inspect}"
      end

      def destroy
        @model.destroy
      end

      def route(http)
        case http.route
          in path: [ _, id ], method: :get
            http.response.write show
          in path: [ _, id, "edit" ], method: :get
            http.response.write edit
          in path: [ _, id ], method: :delete
            destroy
        end
      end
    end

    class Resources
      include Routing

      Resource = Controller::Resource

      def initialize(scope:)
        @scope = scope
      end

      def index
        "All of #{@scope.all.inspect}"
      end

      def route(http)
        case http.route
          in path: [ _ , id, *_ ]
            resource(id).route(http)
          in path: [ _ ], method: :get
            http.response.write index
        end
      end

      protected

      def resource(id)
        self.class::Resource.new(model: @scope.find(id))
      end
    end

  end
end
