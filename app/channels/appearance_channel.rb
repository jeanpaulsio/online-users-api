class AppearanceChannel < ApplicationCable::Channel
  def subscribed
    stream_from "appearance_channel"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
