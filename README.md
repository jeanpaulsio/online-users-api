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

