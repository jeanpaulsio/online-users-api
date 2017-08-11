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
    ActionCable.server.broadcast 'appearance_channel', json_response(@user)
  end

  private

    def user_params
      params.permit(:online)
    end
end
