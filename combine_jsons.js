/*jslint indent: 2, maxlen: 80, continue: false, unparam: false, node: true */
/* -*- tab-width: 2 -*- */
'use strict';

var stocks = {}, categs = require('./categs.json'), factLists = [
  require('./cache/gnome_dev_deprecated.json'),
  require('./cache/gnome_dev_mentions.json'),
  require('./cache/gnome_dev_since.json'),
  require('./cache/icon_files.json'),
  require('./cache/labels.de_de.json'),
  require('./cache/labels.en_us.json'),
  require('./cache/pygtk-icons.json'),
];

function subObj(obj, key) {
  if (!obj[key]) { obj[key] = {}; }
  return obj[key];
}

factLists.forEach(function (factList) {
  Object.keys(factList).forEach(function (stockName) {
    var categ = categs[stockName], newFacts = factList[stockName];
    categ = subObj(stocks, categ);
    Object.assign(subObj(categ, stockName), newFacts);
  });
});

console.log(JSON.stringify(stocks, null, 2));
