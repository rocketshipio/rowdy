# frozen_string_literal: true

RSpec.describe Rowdy do
  it "has a version number" do
    expect(Rowdy::VERSION).not_to be nil
  end

  it "does something useful" do
    class Application
      include Rowdy::Routing

      get def welcome
        "hi"
      end

      get def greet(greeting)
        "Hello #{greeting}"
      end

      get def show(id:)
        "Finding #{id}"
      end

      post def create(title:, description:)
        "Creating #{title} #{description}"
      end

      patch def bulk(ids: [])
        "Do some bulk stuff with all these ids: #{ids.inspect}"
      end
    end

    class SubApplication < Application
      def show(id:)
        "This is the sub-app ... #{id}"
      end
    end

    class Person < Data.define(:name, :age, :id)
      def self.find(id)
        new id: id, age: nil, name: nil
      end
    end

    class Animal < Data.define(:name, :age, :id)
      def self.find(id)
        new id: id, age: nil, name: nil
      end
    end

    class Resource
      include Rowdy::Routing

      def initialize(model:)
        @model = model
      end

      get def show(id:) = "Finding #{@model.find(id).inspect}"
      post def create(**kwargs) = "Creating #{@model.new(**kwargs)}"

      patch def bulk(ids: [])
        models = ids.map { |id| @model.find id }
        "Do some bulk stuff with all these models: #{models.inspect}"
      end
    end

    ### This would be handled by the web server ... dev doesn't see it.

    app = Application.new
    app.call(path: "welcome")
    app.call(path: "create", method: :post, params: {title: "Hi", description: "There"})
    begin
      app.call(path: "create", method: :post, params: {title: "Hi"})
    rescue ArgumentError
      puts "This would return an HTTP code that the request is invalid"
    end
    app.call(path: "show", params: {id: 1})
    app.call(path: "create", method: :post, params: {title: "Hi", description: "There"})
    app.call(path: "bulk", method: :patch, params: {ids: (1..10).to_a})

    # This doesn't inherit the routes yet 😢
    sub_app = SubApplication.new
    sub_app.call(path: "show", params: {id: 1})


    person_resource = Resource.new(model: Person)
    person_resource.call(path: "show", params: {id: 1})
    person_resource.call(path: "bulk", method: :patch, params: {ids: [1,3,7]})

    animal_resource = Resource.new(model: Animal)
    animal_resource.call(path: "show", params: {id: 11})
    animal_resource.call(path: "bulk", method: :patch, params: {ids: [11,33,77]})

    ### Next thing to solve would be mounting apps inside of apps ... so something like this is possible...

    # class Application
    #   mount Resource.new(model: Person),
    #   mount Resource.new(model: Animal), at: "/animals"
    #
    #   get def greet
    #     "Hello! Check out /persons and /animals"
    #   end
    # end

  end
end
