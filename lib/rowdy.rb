# frozen_string_literal: true

require_relative "rowdy/version"

module Rowdy
  class Error < StandardError; end

  class Router
    def routes
      @routes ||= []
    end

    def add(*args)
      routes.append args
    end
  end

  class Dispatcher
    def initialize(application:, router: nil)
      @application = application
      @router = router || application.router
      p [:routes, @router.routes]
    end

    def call(path:, method: :get, params: {})
      p requested_route = [ method.to_sym, path.to_sym ]
      p case @router.routes.find { |route| route == requested_route }
        in [_, action_name]
          action = @application.method(action_name)
          response = action.arity.zero? ? action.call : action.call(**params)
          [ 200, response ]
        in nil
          [ 404, "Not Found" ]
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

    def dispatcher
      Dispatcher.new(application: self)
    end

    def call(...)
      dispatcher.call(...)
    end

    module ClassMethods
      HTTP_METHODS.each do |http_method|
        define_method http_method do |action|
          router.add http_method, action
        end
      end

      def router
        @router ||= Router.new
      end
    end
  end
end
