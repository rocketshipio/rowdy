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

  class Responder
    include Routing

    def text(text, **kwargs)
      respond(text, mime_type: "text/plain", **kwargs)
    end

    def html(html, **kwargs)
      html = html.call if html.respond_to? :call
      respond(html, mime_type: "text/html", **kwargs)
    end

    def json(data, **kwargs)
      respond(JSON.encode(data), mime_type: "applcation/json", **kwargs)
    end

    def respond(content, mime_type:, status: 200)
      @content = content
      @mime_type = mime_type
      @status = status
    end

    def route(http)
      http.response.headers["Content-Type"] = @mime_type
      http.response.status = @status
      http.response.write @content
      http.response.finish
    end
  end

  class Format
    attr_reader :accept

    def initialize(accept:, content_type: nil)
      @accept = accept
      @content_type = content_type || accept
    end

    def route(http)
      http.response["Content-Type"] = @content_type
      http.response.write respond
    end
  end

  class Formats < Set
    def compare_by_identity(object)
      object.accept
    end
  end

  class ResponseNegotiater
    include Routing

    def initialize
      @formats = Formats.new
    end

    def json(&)
      add_format accept: "application/json", content_type: "applcation/json", &
    end

    def html(&)
      add_format accept: "text/html", content_type: "text/html", &
    end

    def text(&)
      add_format accept: "text/plain", content_type: "text/plain", &
    end

    def add_format(**args, &block)
      @formats << Class.new(Format) do
        define_method :respond do
          block.call
        end
      end.new(**args)
    end

    def route(http)
      format = @formats.first # Assume we found it from the reouter
      format.route(http)
    end
  end


  module Controller
    class Resource
      include Routing

      attr_reader :response

      def initialize(model:)
        @model = model
      end

      def show
        response.text { "Showing #{@model.inspect}" }
      end

      def edit
        response.text { "Edit #{@model.inspect}" }
      end

      def destroy
        @model.destroy
      end

      def route(http)
        @response = ResponseNegotiater.new

        case http.route
          in path: [ _, id ], method: :get
            show
          in path: [ _, id, "edit" ], method: :get
            edit
          in path: [ _, id ], method: :delete
            destroy
        end

        @response.route(http)
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
