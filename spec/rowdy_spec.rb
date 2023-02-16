# frozen_string_literal: true

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

class Application
  include Rowdy::Routing

  route "people", to: Resource.new(model: Person)
  route "animals", to: Resource.new(model: Animal)

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

RSpec.describe Rowdy do
  it "has a version number" do
    expect(Rowdy::VERSION).not_to be nil
  end

  context "Application" do
    let(:app) { Application.new }

    it "routes" do
      expect(app.call(path: "welcome")).to eql [ 200, "hi" ]
    end

    it "raises error if params are incorrect" do
      expect{ app.call(path: "create", method: :post, params: {title: "Hi"}) }.to raise_error(ArgumentError)
    end

    it "does not explode" do
      ### This would be handled by the web server ... dev doesn't see it.
      app.call(path: "create", method: :post, params: {title: "Hi", description: "There"})
      app.call(path: "show", params: {id: 1})
      app.call(path: "create", method: :post, params: {title: "Hi", description: "There"})
      app.call(path: "bulk", method: :patch, params: {ids: (1..10).to_a})
    end

    it "deals with resources" do
      person_resource = Resource.new(model: Person)
      person_resource.call(path: "show", params: {id: 1})
      person_resource.call(path: "bulk", method: :patch, params: {ids: [1,3,7]})

      animal_resource = Resource.new(model: Animal)
      animal_resource.call(path: "show", params: {id: 11})
      animal_resource.call(path: "bulk", method: :patch, params: {ids: [11,33,77]})
    end
  end

  context "SubApplication" do
    let(:app) { SubApplication.new }

    it "routes to sub app" do
      # This doesn't inherit the routes yet 😢
      expect(app.call(path: "show", params: {id: 1})).to eql [ 200, "This is the sub-app ... 1" ]
    end
  end
end
