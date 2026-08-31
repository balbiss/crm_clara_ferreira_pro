class NotificationsController < ApplicationController
  before_action :authenticate_user!

  def index
    # Retorna notificações não lidas e as 5 últimas lidas
    scope = current_user.account.notifications.visible_to(current_user)
    unread = scope.where(read_at: nil).order(created_at: :desc)
    read = scope.where.not(read_at: nil).order(created_at: :desc).limit(5)
    
    render json: {
      unread: unread,
      read: read,
      unread_count: unread.count
    }
  end

  def mark_all_read
    current_user.account.notifications.visible_to(current_user).where(read_at: nil).update_all(read_at: Time.current)
    render json: { message: 'Todas marcadas como lidas' }
  end

  def mark_as_read
    notification = current_user.account.notifications.visible_to(current_user).find(params[:id])
    notification.update(read_at: Time.current)
    render json: { message: 'Marcada como lida' }
  end
end
