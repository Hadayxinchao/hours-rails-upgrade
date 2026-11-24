# Serves docs/api/openapi.yaml with this account's address as the server URL.
class ApiDocsController < ActionController::API # read-only, no session: no CSRF surface
  def show
    spec = YAML.safe_load_file(Rails.root.join("docs/api/openapi.yaml"))
    spec["servers"] = [{ "url" => "#{request.base_url}/api/v1" }]
    render plain: spec.to_yaml, content_type: "application/yaml"
  end
end
