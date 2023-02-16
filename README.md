# Rowdy

Rowdy is a gem that makes it possible to route web requests to classes. It does this by breaking routing into three distinct parts:

1. **Dispatching** - The dispatcher takes a `Rack::Request` and makes it suitable for calling a method onto a Rowdy class.
2. **Routing** - Routes are lists that the Dispatcher uses to lookup the class it should route to.
3. **Applications** - Applications are classes that the Dispatcher can route to and fullfill a request.

What's the point of all this? Writing less code! It makes this possible:

```ruby
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

  mount Resource.new(model: Person),
  mount Resource.new(model: Animal), at: "/animals"

  get def greet
    "Hello! Check out /persons and /animals"
  end
end
```

If you tried to do this in Rails, you'd have to generate a controller per resource even though they probably do the same thing.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add rowdy

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install rowdy

## Usage

Create something like this in `app.rb`

```ruby
class Resource
  include Routing

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
  route "people", to: Resource.new(model: Person)
  route "animals", to: Resource.new(model: Animal)

  get def greet
    "Hello! Check out /persons and /animals"
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

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/rowdy. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/rowdy/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Rowdy project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/rowdy/blob/main/CODE_OF_CONDUCT.md).
