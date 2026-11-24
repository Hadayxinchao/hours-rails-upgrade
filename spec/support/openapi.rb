# Validates JSON against docs/api/openapi.yaml, so the docs can't drift from
# what the API returns.
module OpenapiHelper
  DOCUMENT = JSONSchemer.openapi(YAML.safe_load_file(Rails.root.join("docs/api/openapi.yaml")))

  def expect_schema(name, data)
    errors = DOCUMENT.ref("#/components/schemas/#{name}").validate(data).map { |e| e["error"] }
    expect(errors).to be_empty, "#{name} doesn't match openapi.yaml:\n#{errors.join("\n")}"
  end
end

RSpec.configure do |config|
  config.include OpenapiHelper, type: :request
end
