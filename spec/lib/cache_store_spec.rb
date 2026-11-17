# Production uses :mem_cache_store (config/environments/production.rb) but the
# test suite runs with caching off, so a broken dalli/connection_pool combo
# would only surface after deploy. Building the store is enough to catch it.
describe "production cache store" do
  it "can be built with the bundled dalli and connection_pool" do
    store = ActiveSupport::Cache.lookup_store(:mem_cache_store, "localhost:11211", pool: { size: 2 })

    expect(store).to be_a(ActiveSupport::Cache::MemCacheStore)
  end
end
