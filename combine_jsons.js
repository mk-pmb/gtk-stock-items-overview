/*jslint indent: 2, maxlen: 80, continue: false, unparam: false, node: true */
/* -*- tab-width: 2 -*- */
'use strict';

var stocks = {}, categs = require('./cfg/categs.json'), factLists, initFacts;

factLists = [
  require('./tmp/gnome_dev_deprecated.json'),
  require('./tmp/gnome_dev_mentions.json'),
  require('./tmp/gnome_dev_since.json'),
  require('./tmp/icon_files.json'),
  require('./tmp/labels.de_de.json'),
  require('./tmp/labels.en_us.json'),
  require('./tmp/pygtk-icons.json'),
];

initFacts = {
  gnome_dev_defined: false,
  gnome_dev_deprecated: false,
  gnome_dev_since: '?',
  iconfile_pygtk: null,
  label_de_DE: '???',
  label_en_US: '???',
  pygtk_docs_icon_rtl: null,
  pygtk_docs_icon: null,
};

function subObj(obj, key, dflt) {
  if (!obj[key]) { obj[key] = Object.assign({}, dflt); }
  return obj[key];
}

factLists.forEach(function (factList) {
  Object.keys(factList).forEach(function (stockName) {
    var categ = categs[stockName], newFacts = factList[stockName], knownFacts;
    categ = subObj(stocks, categ);
    knownFacts = subObj(categ, stockName, initFacts);
    Object.assign(knownFacts, newFacts);
  });
});

console.log(JSON.stringify(stocks, null, 2));
