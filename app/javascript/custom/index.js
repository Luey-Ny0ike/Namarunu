$(document).on("turbolinks:load", function() {
  $(".box").click(function() {
    $(".content", this).toggle(100);
  });
  $(".question").click(function() {
    $(".content-f", this).toggle(100);
  });
  $("#domain-name-select").change(function() {
    if ($("#domain-name-select").val() == "Yes") {
      $(".preffered_name").hide(150);
    } else if ($("#domain-name-select").val() == "No") {
      $(".preffered_name").show(150);
    } else {
      $(".preffered_name").hide(150);
    }
  });
  $(".switch").click(function() {
    if ($("#billing-switch").is(":checked")) {
      $(".semi-annually").show();
      $(".monthly").hide();
    } else {
      $(".semi-annually").hide();
      $(".monthly").show();
    }
  });
  $(".kenya").click(function() {
    $(".ke").show();
    $(".us").hide();
    $(".tz").hide();
  });
  $(".usa").click(function() {
    $(".us").show();
    $(".ke").hide();
    $(".tz").hide();
  });
  $(".tanzania").click(function() {
    $(".tz").show();
    $(".us").hide();
    $(".ke").hide();
  });
});
