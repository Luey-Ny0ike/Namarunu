$(document).on("turbolinks:load", function() {
  $(".box").click(function() {
    $(".content", this).toggle(100);
  });
  $(".question").click(function() {
    $(".content-f", this).toggle(100);
  });
  $("#domain-name-select").click(function() {
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
});
