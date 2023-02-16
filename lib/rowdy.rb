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
          root: fullpath == "/"
        }
      end
    end

    class Response < Rack::Response
    end

    def self.from_rack(env)
      new request: Request.new(env), response: Response.new
    end
  end

  class Server
    include Routing
  end

  module Action
    class Base
      include Routing

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

      def get_json
        get.to_json
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
    class Resource
      include Routing

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

    class Resources
      include Routing

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
end
