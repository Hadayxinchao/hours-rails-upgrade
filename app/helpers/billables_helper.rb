# The Billables page renders every unbilled entry (10k+ rows on the benchmark
# account). Only ~20 users and ~365 dates repeat across those rows, so build
# each user link and date label once per request instead of once per row.
module BillablesHelper
  def billable_user_link(user)
    (@billable_user_links ||= {})[user.id] ||= link_to(user.full_name, user)
  end

  def billable_date(date)
    (@billable_dates ||= {})[date] ||= I18n.l(date)
  end
end
