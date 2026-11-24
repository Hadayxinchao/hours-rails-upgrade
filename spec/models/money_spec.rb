describe Money do
  it "parses decimal input into minor units, rounding half up" do
    expect(Money.to_minor("85.5", "USD")).to eq 8550
    expect(Money.to_minor("1,234.565", "EUR")).to eq 123_457
    expect(Money.to_minor("250000", "VND")).to eq 250_000
  end

  it "formats minor units with symbol, delimiter and the currency's decimals" do
    expect(Money.format(123_456, "USD")).to eq "$1,234.56"
    expect(Money.format(-500, "EUR")).to eq "-€5.00"
    expect(Money.format(1_500_000, "VND")).to eq "₫1,500,000"
  end

  it "formats form values with the currency's decimals" do
    expect(Money.to_input(8550, "USD")).to eq "85.50"
    expect(Money.to_input(250_000, "VND")).to eq "250000"
    expect(Money.to_input(nil, "USD")).to be_nil
  end

  it "round-trips through to_decimal" do
    expect(Money.to_decimal(8550, "USD")).to eq BigDecimal("85.5")
  end
end
