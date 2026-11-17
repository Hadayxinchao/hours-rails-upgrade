# Production uses Solid Cache (config/environments/production.rb) but the
# test suite runs with caching off, so an incompatible cache gem would only
# surface after deploy. Building the store is enough to catch that.
describe "production cache store" do
  it "builds a Solid Cache store" do
    expect(ActiveSupport::Cache.lookup_store(:solid_cache_store))
      .to be_a(SolidCache::Store)
  end
end
