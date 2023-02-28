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

class Application
  include Rowdy::Routing

  def route(http)
    case http
      in format: :html
        html << "<h1>Hello friend</h1>"
      in format: :plain
        plain << "Hello friend"
    end
  end
end

RSpec.describe Rowdy do
  it "has a version number" do
    expect(Rowdy::VERSION).not_to be nil
  end

  context "Application" do
    let(:app) { Application.new }
  end
end

RSpec.describe Rowdy::AcceptParser do
  let(:header) { "text/html, application/xhtml+xml, application/xml;q=0.9, */*;q=0.8" }
  let(:parser) { Rowdy::AcceptParser.new(header) }
  let(:html_type) { Rowdy::AcceptParser::Type.new(media_type: "text", sub_type: "html", weight: nil) }

  describe "#types" do
    context "first type" do
      subject { parser.types.first }
      it { is_expected.to eql(html_type) }
    end
  end
end
