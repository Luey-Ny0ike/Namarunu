import $ from "jquery";
window.$ = $;
window.jQuery = $;

$(document).ready(function() {
  // Initialize visibility states
  $(".monthly").hide();
  $(".us").hide();
  $(".tz").hide();
  
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
  $("#billing-switch").change(function() {
    if ($(this).is(":checked")) {
      $(".semi-annually").show();
      $(".monthly").hide();
    } else {
      $(".semi-annually").hide();
      $(".monthly").show();
    }
  });
  $("#inputCurrency").change(function() {
    var selectedCurrency = $(this).val();
    if (selectedCurrency === "KES") {
      $(".ke").show();
      $(".us").hide();
      $(".tz").hide();
    } else if (selectedCurrency === "$") {
      $(".us").show();
      $(".ke").hide();
      $(".tz").hide();
    } else if (selectedCurrency === "TZS") {
      $(".tz").show();
      $(".us").hide();
      $(".ke").hide();
    }
  });
});
