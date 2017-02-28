class Users::CheckinsController < ApplicationController
  protect_from_forgery except: :show

  before_action :authenticate_user!
  before_action :require_checkin_ownership, except: [:index, :new, :create, :destroy_all]
  before_action :require_device_ownership, only: [:index, :new, :create, :destroy_all]
  before_action :find_checkin, only: [:show, :update, :destroy]

  def new
    @checkin = Device.find(params[:device_id]).checkins.new
  end

  def index
    per_page = params[:per_page].to_i <= 1000 ? params[:per_page] : 1000

    render json: {
      checkins: device
        .checkins
        .paginate(page: params[:page], per_page: per_page)
        .select(:id, :lat, :lng, :created_at, :address, :fogged, :fogged_city, :device_id),
      current_user_id: current_user.id,
      total: device.checkins.count
    }
  end

  def create
    @checkin = device.checkins.create(checkin_params)
    device.notify_subscribers('new_checkin', @checkin)

    flash[:notice] = 'Checked in.'
  end

  def show
    @checkin.reverse_geocode!
  end

  def update
    if params[:checkin]
      @checkin.update(checkin_params)
      @checkin.refresh
      return render status: 200, json: @checkin unless @checkin.errors.any?
      render status: 400, json: @checkin.errors.messages
    else
      @checkin.switch_fog
    end
  end

  def destroy
    @checkin.delete

    flash[:notice] = 'Check-in deleted.'
  end

  def destroy_all
    Checkin.where(device: params[:device_id]).delete_all
    flash[:notice] = 'History deleted.'
    redirect_to user_device_path(current_user.url_id, params[:device_id])
  end

  private

  def device
    @device ||= Device.find(params[:device_id])
  end

  def find_checkin
    @checkin = Checkin.find(params[:id])
  end

  def checkin_params
    params
      .require(:checkin)
      .permit(:lat, :lng, :device_id, :fogged)
  end

  def require_checkin_ownership
    return if user_owns_checkin?

    flash[:alert] = 'You do not own that check-in.'
    redirect_to root_path
  end

  def require_device_ownership
    return if current_user.devices.exists?(params[:device_id])

    flash[:alert] = 'You do not own this device.'
    redirect_to root_path
  end
end
