class InternalChatChannel < ApplicationCable::Channel
  def subscribed
    stream_from "internal_chat_channel_#{current_user.account_id}"
  end

  def unsubscribed
  end
end
