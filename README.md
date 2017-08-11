# Quick API Setup

```
$ rails new users-api --api --database=postgresql
$ rails db:setup
$ rails db:migrate

$ rails g model User name online:boolean
$ rails db:migrate
```

## Create a Couple of Seeds

```ruby
# db/seeds.rb
User.create(name: "JP", online: true);
User.create(name: "John", online: false);
User.create(name: "Dale", online: false);
```
```
$ rails db:seed
```

## Create Routes

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

We want our setup to look like this:

```
├── controllers
│   ├── api
│   │   ├── v1
│   │   │   └── api_controller.rb
│   │   │   └── users_controller.rb
```

```
$ rails g controller api/v1/Api
$ rails g controller api/v1/Users
```

First we set up our `users_controller`

```ruby
# controllers/api/v1/users_controller.rb

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

Then we set up our `json_response` helper method

```ruby
# app/controllers/concerns/response.rb

module Response
  def json_response(object, status = :ok)
    render json: object, status: status
  end
end
```

Make sure to include the `Response` module in your `api_contoller`

```ruby
# controllers/api/v1/api_controller.rb
class Api::V1::ApiController < ApplicationController
  include Response
end
```

(look ma, no tests)

## Serializing Output + Enabling CORS
* Active Model Serializers gives us a clean layer between the model and the controller
* Normally we would use something like jbuilder but we have no views in our API-only Rails app

```ruby
# Gemfile

gem 'active_model_serializers'
gem 'rack-cors'
```

```
$ bundle install
$ rails g serializer user
```

```ruby
# app/serializers/user_serializer.rb
class UserSerializer < ActiveModel::Serializer
  attributes :id, :name, :online
end
```

* Building a Public API means you want to enable Cross-Origin Resource Sharing (CORS)
* This needs to be enabled if you want to make AJAX requests

```ruby
# config/application.rb

# ...
config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins '*'
    resource '*', :headers => :any, :methods => [:get, :post, :options, :delete]
  end
end
# ...
```

__Voila - a quick and dirty API with 2 endpoints__

```
GET     /api/v1/users
PUT     /api/v1/users/:id
```

## SPOOKY ACTION CABLE WEB SOCKETS STUFF

For more, visit [Hartl's Tutorial](https://www.learnenough.com/action-cable-tutorial)

* First we generate an action cable channel
* We'll call this channel `Appearance` so we can track if a user is online or offline

```
$ rails g channel Appearance
```

* The goal is to have users subscribe to a certain channel so that we can update their browser (or in this case, their mobile app view)
* `stream_from "appearance_channel"`

```ruby
# app/channels/appearance_channel.rb

class AppearanceChannel < ApplicationCable::Channel
  def subscribed
    stream_from "appearance_channel"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
```
* Now let's go back to our endpoint and listen for changes on our `update` method
* We will broadcast to the `appearance_channel` every time the `update` method is invoked
* For example, when we patch a user and set `online` to false, we can see this update in real-time

```ruby
def update
  @user = User.find(params[:id])
  @user.update(user_params)
  ActionCable.server.broadcast 'appearance_channel', json_response(@user)
end
```

* Next, we mount our Action Cable server in our `config/routes.rb` file

```ruby
mount ActionCable.server, at: '/cable'
```

* And *that's it for the backend!*
* Let's deploy

### Action Cable Deployment

```ruby
# Gemfile
gem 'redis', '~> 3.0'
```

```
$ bundle install
$ heroku create
$ heroku addons:create redistogo
$ heroku config | grep REDISTOGO_URL
```

```ruby
# config/cable.yml

production:
  adapter: redis
  url: ${REDISTOGO_URL}
```

```ruby
# config/environments/production.rb

config.action_cable.url = 'wss://yourapp.herokuapp.com/cable'
config.action_cable.allowed_request_origins = [ '*' ]
```

```
$ git add .
$ git commit -m 'ready to ship'
$ git push heroku master

$ heroku run rails db:migrate
$ heroku run rails db:seed
```

## React-Native Steps to Victory

* Create a new project with expo, here we call it `online-users`
* Let's grab a few things

```
$ cd online-users
$ npm install --save axios react-native-actioncable
```

* Open up `App.js` and let's do a simple fetch of our 3 seeded users

```
import React from "react";
import { StyleSheet, Text, View } from "react-native";
import axios from "axios";

export default class App extends React.Component {
  state = {
    userList: []
  };

  async componentDidMount() {
    let userList = await axios.get(
      "https://ac-test-temp.herokuapp.com/api/v1/users"
    );
    this.setState({ userList: userList.data });
  }

  render() {
    return (
      <View style={styles.container}>
        {this.state.userList &&
          this.state.userList.map(user => {
            return (
              <View key={user.id}>
                <Text>
                  {user.name}
                  {user.online && <View style={styles.online} />}
                </Text>
              </View>
            );
          })}
      </View>
    );
  }
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#fff",
    alignItems: "center",
    justifyContent: "center"
  },
  online: {
    height: 8,
    width: 8,
    borderRadius: 4,
    backgroundColor: "green"
  }
});

```

* Cool, so we're fetching users. Now let's wire up action cable

```
import React from "react";
import { StyleSheet, Text, View } from "react-native";
import axios from "axios";
import ActionCable from "react-native-actioncable";

export default class App extends React.Component {
  state = {
    userList: []
  };

  cable = ActionCable.createConsumer("wss://ac-test-temp.herokuapp.com/cable");

  async componentDidMount() {
    let userList = await axios.get(
      "https://ac-test-temp.herokuapp.com/api/v1/users"
    );
    this.setState({ userList: userList.data });

    this.cable.subscriptions.create("AppearanceChannel", {
      received: data => {
        let item = JSON.parse(data);
        let index = this.state.userList.findIndex(user => user.id === item.id);
        let updatedUserList = [
          ...this.state.userList.slice(0, index),
          item,
          ...this.state.userList.slice(index + 1)
        ];
        this.setState({ userList: updatedUserList });
      }
    });
  }

  render() {
    return (
      <View style={styles.container}>
        <Text style={{fontWeight: '600'}}>Users</Text>
        {this.state.userList &&
          this.state.userList.map(user => {
            return (
              <View key={user.id}>
                <Text>
                  {user.name}
                  {user.online && <View style={styles.online} />}
                </Text>
              </View>
            );
          })}
      </View>
    );
  }
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#fff",
    alignItems: "center",
    justifyContent: "center"
  },
  online: {
    height: 8,
    width: 8,
    borderRadius: 4,
    backgroundColor: "green"
  }
});

```







