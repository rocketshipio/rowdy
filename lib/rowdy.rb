# frozen_string_literal: true

require_relative "rowdy/version"
require "rack"

module Rowdy
  class Error < StandardError; end

  module Routing
    def dispatch(http)
      route http
      http.response.to_a
    end
  end

  class AcceptParser
    class Type < Data.define(:media_type, :sub_type, :weight)
      # Parses `text/html;q=0.9`, etc.
      REGEXP = /([\w+*]+)\/([\w+*-]+)(?:\s*;\s*q=(\d(?:\.\d)?))?/

      def mime_type
        [media_type, sub_type].join("/")
      end
    end

    def initialize(accept)
      @accept = accept
    end

    def types
      @accept.scan(Type::REGEXP).map do |media_type, sub_type, weight|
        Type.new \
          media_type: media_type,
          sub_type: sub_type,
          weight: weight
      end
    end
  end

  class Format
    attr_reader :extension

    def initialize(transaction)
      @transaction = transaction
      @types = AcceptParser.new(transaction.request.env["HTTP_ACCEPT"]).types
    end

    class Responder
      def initialize(response:, type:)
        @response = response
        @type = type
      end

      def write(...)
        @response.headers["Content-Type"] = @type.mime_type
        @response.write(...)
      end
      alias :<< :write
    end

    def format_bindings
      @types.map do |type|
        [
          type.sub_type.to_sym,
          Responder.new(response: @transaction.response, type: type)
        ]
      end
    end

    def deconstruct_keys(*)
      Hash[*format_bindings.flatten]
    end

    def write(content)
      @transaction.response.headers["Content-Type"] = @content_type
      @transaction.response.write(content)
    end
    alias :<< :write
  end

  class Route
    def initialize(transaction)
      @transaction = transaction
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

  class Transaction
    attr_reader :request, :response

    Request = Class.new(Rack::Request)
    Response = Class.new(Rack::Response)

    def define(name, &)
      self.define_singleton_method name, &
      self
    end

    def initialize(request:, response:)
      @request = request
      @response = response
    end

    def route
      @route ||= Route.new(self)
    end

    def format
      @format ||= Format.new(self)
    end

    def deconstruct_keys(*)
      { format: format, route: route }
    end

    def self.from_rack(env)
      new request: Request.new(env), response: Response.new
    end
  end

  class Server
    include Routing

    Transaction = Transaction

    def call(env)
      dispatch self.class::Transaction.from_rack env
    end
  end

  module Controller
    class Resource
      include Routing

      def initialize(model:)
        @model = model
      end

      def show(http)
        "Showing #{@model.inspect}"
      end

      def edit(http)
        "Editing #{@model.inspect}"
      end

      def destroy(http)
        @model.destroy
      end

      def route(http)
        case http.route
          in path: [ _, id ], method: :get
            show http
          in path: [ _, id, "edit" ], method: :get
            edit http
          in path: [ _, id ], method: :delete
            destroy http
        end
      end
    end

    class Resources
      include Routing

      Resource = Controller::Resource

      def initialize(scope:)
        @scope = scope
      end

      def index(http)
        "All of #{@scope.all.inspect}"
      end

      def route(http)
        case http.route
          in path: [ _ , id, *_ ]
            resource(id).route(http)
          in path: [ _ ], method: :get
           index http
        end
      end

      protected

      def resource(id)
        self.class::Resource.new(model: @scope.find(id))
      end
    end

  end
end
