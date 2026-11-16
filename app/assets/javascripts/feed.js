// Converted from CoffeeScript (feed.js.coffee) during the Rails 7 upgrade.
(function() {
  $(function() {
    return $(".timestamp").each(function(_, timestamp) {
      var daysAgo, formatter, locale;
      timestamp = $(timestamp);
      locale = $("body").data("language");
      formatter = new DateFormatter(timestamp.data("timestamp"), locale);
      daysAgo = formatter.daysAgoInWords();
      return timestamp.html(daysAgo);
    });
  });

}).call(this);
