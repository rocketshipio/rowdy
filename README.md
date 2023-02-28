# Rowdy

Rowdy is a gem that takes a PORO approach to Ruby web routing using modern Ruby features, like pattern matching. Here's what Rowdy looks like in action.

```ruby
Blog = Data.define(:title, :description)
Post = Data.define(:title, :body)

class Application
  include Rowdy::Routing

  def initialize(model:)
    @model = model
  end

  def route(http)
    http.response.headers["Content-Type"] = "text/plain"
    http.response.status = 200

    case http.route
      in root: true
        http.response.write "Hello from Rowdy!"
      in "blogs", id, *_
        Rowdy::Controller::Resources.new(scope: Blog).route(http)
      in "posts", id, *_
        Rowdy::Controller::Resources.new(scope: Post).route(http)
      else
        http.response.status = 404
        http.response.write "Not Found"
    end
  end
end
```

If you tried to do this in Rails, you'd have to generate a controller per resource even though they probably do the same thing. Since Rowdy embraces a full PORO approach to building web applications, you can compose classes in a very object-oriented way.

## Middleware

Because Rowdy is PORO, you can use `Module.prepend` to add Middleware to your applicatons. Here's an example of how you might extend a controller with authentication.

```ruby
module Authentication
  def route(http)
    if Rack::Auth::Basic::Request.new(http.request.env).provided?
      super http
    else
      http.response['WWW-Authenticate'] = %(Basic realm="Super duper ultra-secret area")
      http.response.write "Authenticate with any username and password"
      http.response.status = 401
    end
  end
end

module Logging
  def route(http)
    puts "You're requesting some stuff"
    super http
  end
end

class SecretApplication
  include Rowdy::Routing

  prepend Authentication
  prepend Logging

  def route(http)
    http.response.write "Your fridge is running, you better go catch it!"
  end
end
```

## Content negotation

RESTful web applications need a way to detect the request format and respond with the appropriate format. Rowdy has content negotation built-in via the `http.format` object, which makes it possible to pattern match and assign the requested format and respond appropriately.

```ruby
class Application
  include Rowdy::Routing

  def route(http)
    case http.format
      in html:
        html.write "<h1>Hello world!</h1>"
      in json:
        json.write "{'hello': 'world'}"
      in plain:
        plain.write "Hello world"
  end
end
```

# Concepts

Rowdy is composed if the three follow concepts:

* **Application** - This is the main routing file, as depicted above.

* **Controller** - Controllers are a collection of similar Actions, but not like you're thinking. In Rails, a controller has various methods that are actions. If you want to do things before and after the action, you're going to get stuck in callback soup. Rowdy is different in that action action is a class, so you can create a `ProtectedAction` subclass that requires a login, then use that subclass in the controller.

* **Action** - An action is a plain 'ol Ruby object that includes `Rowdy::Routing`.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add rowdy

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install rowdy

## Usage

Create something like this in `app.rb`

```ruby
Blog = Data.define(:title, :description)
Post = Data.define(:title, :body)

class Application
  include Rowdy::Routing

  def initialize(model:)
    @model = model
  end

  def route(http)
    http.response.headers["Content-Type"] = "text/plain"
    http.response.status = 200

    case http.route
      in root: true
        http.response.write "Hello from Rowdy!"
      in "blogs", id, *_
        Rowdy::Controller::Resources.new(scope: Blog).route(http)
      in "posts", id, *_
        Rowdy::Controller::Resources.new(scope: Post).route(http)
      else
        http.response.status = 404
        http.response.write "Not Found"
    end
  end
end
```

Then mount it in the config.ru file:

```ruby
require_relative "./app"

run Application.new
```

The run it.

```
rackup config.ru
```

## Prior art

The idea of PORO Ruby web frameworks have been around forever, starting with [camping](https://github.com/camping/camping). Since then Ruby has a *ton* of really amazing web & routing frameworks. This section is intended to answer the question, "why Rowdy?". It is **not** intended to dunk on any other Ruby web or routing frameworks.

### Camping

Camping get's the closest to what I want. Consider the example code on the [camping Github repo](https://github.com/camping/camping).

```ruby
require 'camping'

Camping.goes :Blog

module Blog::Models
  class Post < Base; belongs_to :user; end
  class Comment < Base; belongs_to :user; end
  class User < Base; end
end

module Blog::Controllers
  class Index
    def get
      @posts = Post.find :all
      render :index
    end
  end
end

module Blog::Views
  def layout
    html do
      head { title "My Blog" }
      body do
        h1 "My Blog"
        self << yield
      end
    end
  end

  def index
    @posts.each do |post|
      h1 post.title
    end
  end
end
```

Everything looks fine at first glance, but if you try to extend `Blog::Controllers`, you can't because it's a module. Instead you'd have to do something like this:

```ruby
module ExtendedBlog::Controllers
  Index = Blog::Controllers::Index
  # Example above leaves out all the other actions you'd have to manually extend...
  Show = Blog::Controllers::Show
  Edit = Blog::Controllers::Edit
  Delete = Blog::Controllers::Delete
end
```

Zoiks! That's no fun.

Rowdy gets around that with the concept of a `Rowdy::Controller` class being a very loose association of `Rowdy::Action` classes. The `Rowdy::Controller` has the methods you'd expect, `#index`, `#show`, etc., but they create instances of `Rowdy:Action` classes with the context you'd expect.

### Roda

TODO

### Sinatra

TODO

### Rails

TODO

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/rocketshipio/rowdy. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/rocketshipio/rowdy/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Rowdy project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/rocketshipio/rowdy/blob/main/CODE_OF_CONDUCT.md).
