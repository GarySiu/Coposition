class  Api::V1::Users::PermissionsController < Api::ApiController
  respond_to :json
  
  acts_as_token_authentication_handler_for User
  
  before_action :check_user

  def update
    permission = Permission.find(params[:id])
    permission.update(allowed_params)
    render json: permission
  end

  private
    def allowed_params
      params.require(:permission).permit(:privilege, :bypass_fogging, :show_history)
    end

    def check_user
      unless current_user?(params[:user_id])
        render status: 403, json: { message: 'Incorrect User' }
      end
    end
end
