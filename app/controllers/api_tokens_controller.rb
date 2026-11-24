# Personal API tokens of the signed-in user. A new token is shown once.
class ApiTokensController < ApplicationController
  def index
    @tokens = current_user.api_tokens.order(created_at: :desc)
  end

  def create
    token = ApiToken.issue(user: current_user, name: params.dig(:api_token, :name))
    if token.save
      @new_token = token.plaintext
      flash.now[:notice] = t("api_tokens.created")
    else
      flash.now[:alert] = token.errors.full_messages.to_sentence
    end
    @tokens = current_user.api_tokens.order(created_at: :desc)
    render :index, status: token.persisted? ? :created : :unprocessable_content
  end

  def destroy
    current_user.api_tokens.find(params[:id]).revoke!
    redirect_to api_tokens_path, notice: t("api_tokens.revoked")
  end
end
