$(document).on("turbolinks:load", function() {
  $(".box").click(function() {
    $(".content", this).toggle(100);
  });
  $(".question").click(function() {
    $(".content-f", this).toggle(100);
  });
});
