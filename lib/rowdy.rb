# frozen_string_literal: true

require_relative "rowdy/version"

module Rowdy
  class Error < StandardError; end

  class Route < Data.define(:path, :method)
  end

  class Request < Data.define(:path, :method, :params)
    def route
      Route.new(path: path, method: method)
    end

    def params
      Hash[super.map{ |k ,v| [k.to_sym, v] }]
    end
  end

  class Router
    def routes
      @routes ||= []
    end

    def add(method, path)
      routes.append Route.new(path: path, method: method)
    end
  end

  class Dispatcher
    def initialize(application:, router: nil)
      @application = application
      @router = router || application.router
    end

    def call(env)
      rack = ::Rack::Request.new(env)
      # This is a really lousy way of capturing `foo` from `/foo/bar/bizz/buzz`.
      _, path, *_ = rack.path.split("/")

      request_method = rack.request_method.downcase.to_sym

      request Request.new \
        path: path.to_sym,
        params: rack.params,
        method: request_method
    end

    def request(req)
      if match = @router.routes.find{ |route| route == req.route }
        action = @application.public_method(match.path)
        response = action.arity.zero? ? action.call : action.call(**req.params)
        [ 200, { "Content-Type" => "text/plain" }, [ response ] ]
      else
        [ 404, { "Content-Type" => "text/plain" }, "Not Found" ]
      end
    end
  end

  module Routing
    HTTP_METHODS = %i[get put patch post delete]

    def self.included(base)
      base.extend ClassMethods
    end

    def router
      self.class.router
    end

    # def dispatcher
    #   Dispatcher::Base.new(application: self)
    # end

    def rack
      Dispatcher.new(application: self)
    end

    def call(...)
      rack.call(...)
    end

    def request(...)
      rack.request(...)
    end

    module ClassMethods
      HTTP_METHODS.each do |http_method|
        define_method http_method do |action|
          router.add http_method, action
        end
      end

      def route(app, *args, **kwargs)
        p [:route, app, *args, **kwargs]
      end

      def router
        @router ||= Router.new
      end
    end
  end
end
