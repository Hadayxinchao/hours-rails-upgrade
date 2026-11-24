describe HoursValue do
  it "normalizes sums for display and JSON" do
    expect(HoursValue.normalize(BigDecimal("12.00"))).to eql 12
    expect(HoursValue.normalize(BigDecimal("7.75"))).to eql 7.75
    expect(HoursValue.normalize(nil)).to be_nil
  end

  it "rounds timer durations up to the next quarter hour, at least one" do
    expect(HoursValue.from_seconds(5)).to eql 0.25
    expect(HoursValue.from_seconds(15 * 60)).to eql 0.25
    expect(HoursValue.from_seconds(47 * 60)).to eql 1
    expect(HoursValue.from_seconds(61 * 60)).to eql 1.25
  end
end
