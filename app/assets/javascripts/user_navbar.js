// Converted from CoffeeScript (user_navbar.js.coffee) during the Rails 7 upgrade.
(function() {
  jQuery(function() {
    $("#user-nav").click(function(event) {
      event.stopPropagation();
      $(".dropdown-content").toggle();
      return $(".dropdown-arrow").toggle();
    });
    return $("html").click(function() {
      $(".dropdown-content").hide();
      return $(".dropdown-arrow").hide();
    });
  });

}).call(this);
