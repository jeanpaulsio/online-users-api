# Quick API Setup

```
rails new users-api --api --database=postgresql
rails db:setup
rails db:migrate

rails g model User name online:boolean
rails db:migrate
```

## Name-spacing Routes

```ruby
# config > routes

Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :users
    end
  end
end
```

## Controller Setup
* Goal is to have this

```
├── controllers
│   ├── api
│   │   ├── v1
│   │   │   └── api_controller.rb
│   │   │   └── lists_controller.rb
│   │   │   └── items_controller.rb
```

```
rails g controller api/v1/Api
rails g controller api/v1/Users
```

__users_controller__

```ruby
class Api::V1::UsersController < Api::V1::ApiController
  # GET api/v1/users
  def index
    @users = User.all
    json_response(@users)
  end

  # PUT api/v1/users/:id
  def update
    @user = User.find(params[:id])
    @user.update(user_params)
    json_response(@user)
  end

  private

    def user_params
      params.permit(:online)
    end
end
```

*look ma, no tests*

```ruby
# app/controllers/concerns/response.rb

module Response
  def json_response(object, status = :ok)
    render json: object, status: status
  end
end
```

## Serializing Output + Enabling CORS

```
gem 'active_model_serializers'
gem 'rack-cors'

bundle install
```

* Inside `config/application.rb`

```ruby
config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'
    resource '*', :headers => :any, :methods => [:get, :post, :options, :delete]
  end
end
```

__and voila, a quick and dirty API with 2 endpoints__

```
GET     /api/v1/users
PUT     /api/v1/users/:id
```

## SPOOKY ACTION CABLE WEB SOCKETS STUFF

```
rails generate channel Appearance
```

* Open up this stream and `stream_from` "appearance_channel"

```ruby
# app/channels/appearance_channel.rb

  #...

  def subscribed
    stream_from "appearance_channel"
  end

  # ...
```

* make endpoint streamable?

```ruby
  def update
    @user = User.find(params[:id])
    @user.update(user_params)
    ActionCable.server.broadcast 'appearance_channel', json_response(@user)
  end
```

* mount it in `config/routes`

```ruby
mount ActionCable.server, at: '/cable'
```

### Action Cable Deployment

```ruby
# Gemfile
gem 'redis', '~> 3.0'
```

```
bundle install
heroku create
heroku addons:create redistogo
heroku config | grep REDISTOGO_URL
```

```ruby
# config/cable.yml

production:
  adapter: redis
  url: ${REDISTOGO_URL}
```

```ruby
# config/environments/production.rb


  config.action_cable.url = 'wss://ac-users-api.herokuapp.com/cable'
  config.action_cable.allowed_request_origins = [
    'https://ac-users-api.herokuapp.com' ]
```

```
git add .
git commit -m 'heroku prep'
git push heroku master

heroku run rails db:migrate
heroku run rails db:seed
```

... onto the client?

## React-Native Steps to Victory?

```
npm install --save react-actioncable-provider react-native-actioncable
```






