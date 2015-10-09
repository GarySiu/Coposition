class Api::V1::Users::Devices::CheckinsController < Api::ApiController
  respond_to :json

  before_action :authenticate, :check_user_approved_developer, :find_device

  def last
		checkin = @device.checkins.last
    if params[:type] == "address"
      render json: { uuid: checkin.uuid,
        address: "#{checkin.city}, #{checkin.country}"
      }
    else
    	render json: checkin.slice(:id, :uuid, :lat, :lng)
    end
  end

end