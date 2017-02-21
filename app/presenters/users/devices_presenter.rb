module Users
  class DevicesPresenter
    attr_reader :user
    attr_reader :devices
    attr_reader :device
    attr_reader :checkins
    attr_reader :filename
    attr_reader :config
    attr_reader :from
    attr_reader :to

    def initialize(user, params, action)
      @user = user
      @params = params
      send action
    end

    def index
      devices = @user.devices
      devices.geocode_last_checkins
      device_ids = devices.last_checkins.map { |checkin| checkin['device_id'] }
      devices = devices.index_by(&:id).values_at(*device_ids)
      devices += @user.devices.includes(:permissions)
      @devices = devices.uniq.paginate(page: @params[:page], per_page: 5)
    end

    def show
      @device = Device.find(@params[:id])
      @from, @to = date_range
      return unless (download_format = @params[:download])
      @filename = "device-#{@device.id}-checkins-#{Date.today}." + download_format
      @checkins = @device.checkins.send('to_' + download_format)
    end

    def shared
      @device = Device.find(@params[:id])
      @checkin = @device.checkins.before(@device.delayed.to_i.minutes.ago).first.reverse_geocode!
    end

    def info
      @device = Device.find(@params[:id])
      @config = @device.config
    end

    def index_gon
      {
        checkins: gon_index_checkins,
        current_user_id: @user.id,
        devices: @devices,
        permissions: @devices.map { |device| device.permissions.not_coposition_developers }.inject(:+)
      }
    end

    def show_gon
      {
        checkins: show_checkins,
        device: @device.id,
        current_user_id: @user.id,
        total: @device.checkins.count
      }
    end

    def shared_gon
      {
        device: @device.public_info,
        user: @device.user.public_info_hash,
        checkin: gon_shared_checkin
      }
    end

    private

    def gon_index_checkins
      checkins = @user.devices.map do |device|
        device.checkins.first.as_json.merge(device: device.name) if device.checkins.exists?
      end.compact
      checkins.sort_by { |checkin| checkin['created_at'] }.reverse
    end

    def gon_shared_checkin
      Checkin.where(id: @checkin.id)
             .select('id', 'created_at', 'updated_at', 'device_id', 'output_lat AS lat', 'output_lng AS lng',
                     'output_address AS address', 'output_city AS city', 'output_postal_code AS postal_code',
                     'output_country_code AS country_code')[0]
    end

    def show_checkins
      @device.checkins.where(created_at: @from..@to).paginate(page: 1, per_page: 1000)
             .select(:id, :lat, :lng, :created_at, :address, :fogged, :fogged_city, :edited)
    end

    def date_range
      if @params[:from].present?
        return Date.parse(@params[:from]).beginning_of_day, Date.parse(@params[:to]).end_of_day
      elsif @device.checkins.present?
        most_recent = Date.parse(@device.checkins.first.created_at.to_s)
        return (most_recent << 1).beginning_of_day, most_recent.end_of_day
      else 
        return nil, nil
      end
    end
  end
end
