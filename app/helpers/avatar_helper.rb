require "digest/md5"

# Replaces the unmaintained gravatar_image_tag gem (it calls URI.escape,
# which was removed in Ruby 3.0).
module AvatarHelper
  GRAVATAR_HOST = "https://secure.gravatar.com/avatar/".freeze

  # d=blank returns a transparent image when the user has no Gravatar, so the
  # coloured initials behind it stay visible (the old gem's :blank default).
  def gravatar_url(email, size: nil)
    hash = Digest::MD5.hexdigest(email.to_s.strip.downcase)
    params = { d: "blank", s: size }.compact
    "#{GRAVATAR_HOST}#{hash}?#{params.to_query}"
  end

  # Decorative: the surrounding link already shows the user's initials and
  # carries a title, so an empty alt avoids announcing the name twice.
  def avatar_image_tag(user, **options)
    image_tag(gravatar_url(user.email), { alt: "" }.merge(options))
  end
end
