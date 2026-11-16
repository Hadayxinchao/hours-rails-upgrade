class ClientBillableValidator < ActiveModel::Validator
  def validate(record)
    if record.billable && !record.client
      record.errors.add(:client, I18n.t("project.errors.client_missing"))
    end
  end
end
