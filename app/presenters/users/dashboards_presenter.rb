module Users
  class DashboardsPresenter
    NUMBER_OF_CITIES = 5
    NUMBER_OF_COUNTRIES = 10
    MONTH_CHECKINS_LIMIT = 200
    MONTH_CHECKINS_SAMPLE = 100

    def initialize(user)
      @user = user
    end

    def percent_change
      checkins.percentage_increase("week")
    end

    def most_frequent_areas
      checkins.hash_group_and_count_by(:fogged_city).first(NUMBER_OF_CITIES)
    end

    def most_used_device
      Device.find(device_checkins_count.first.first) unless device_checkins_count.empty?
    end

    def last_countries
      last_countries_sql = "created_at IN(SELECT MAX(created_at) FROM checkins INNER JOIN devices ON"\
        " checkins.device_id = devices.id WHERE devices.user_id = #{@user.id} GROUP BY country_code)"
      checkins.where(last_countries_sql).first NUMBER_OF_COUNTRIES
    end

    def gon
      # gon converts these using #each_pair into seperate gon variables
      {
        current_user: current_user_info,
        friends: friends,
        months_checkins: months_checkins
      }
    end

    def visited_countries_title
      case count = last_countries.count
      when 1
        "Last country visited"
      when 0
        "No countries visited"
      else
        "Last #{count} countries visited"
      end
    end

    def weeks_checkins_count
      checkins.where(created_at: 1.week.ago..Time.current).count
    end

    private

    def checkins
      @checkins ||= @user.checkins
    end

    def device_checkins_count
      checkins.hash_group_and_count_by(:device_id)
    end

    def friends
      @user.friends.map do |friend|
        {
          userinfo: friend.public_info_hash,
          lastCheckin: friend.safe_checkin_info_for(permissible: @user, action: "last")[0]
        }
      end
    end

    def months_checkins
      checkins.where(created_at: 1.month.ago..Time.current).limit(MONTH_CHECKINS_LIMIT).sample(MONTH_CHECKINS_SAMPLE)
    end

    def current_user_info
      {
        userinfo: @user.public_info_hash,
        lastCheckin: checkins.first
      }
    end
  end
end
