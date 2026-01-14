require("@rails/ujs").start();
require("@rails/activestorage").start();
require("./channels");

import $ from "jquery";
window.$ = $;
window.jQuery = $;

import "bootstrap";
require("./custom");

