/*jslint indent: 2, maxlen: 80, continue: false, unparam: false, node: true */
/* -*- tab-width: 2 -*- */
'use strict';

var data = require(process.env.COMBO_JSON), cl = console.log,
  unicodeEntities = {
    fullwidthSolidus: '\uFF0F',
  },
  urls = {
    pyGtkDoc: 'http://web.archive.org/web/9900/http://pygtk.org/docs/pygtk/',
    ubuntuIconsGhp: 'https://mk-pmb.github.io/ubuntu-icon-theme-',
    ubuntuIconsRepo: 'https://github.com/mk-pmb/ubuntu-icon-theme-',
  },
  cellNone = unicodeEntities.fullwidthSolidus;

function sorted(arr) { return (arr.sort() || arr); }
function sortedKeys(obj) { return sorted(Object.keys(obj)); }

function relabel(name, props, lang) {
  return ((props['label_' + lang] || '').replace(/_(\S)/g, '<u>$1</u>')
    || cellNone || '??' + name);
}

function pyGtkWebIcon(subPath, alt) {
  if (!subPath) { return ''; }
  var imgUrl = urls.pyGtkDoc + subPath;
  return '[![PyGTK' + (alt || '') + '](' + imgUrl + ')](' + imgUrl + ') ';
}

function ubuntuWebIcon(fn) {
  if (!fn) { return ''; }
  fn = fn.replace(/^\/usr\/share\/icons\//, '').split(/\//);
  fn = [fn[0].toLowerCase()].concat(fn);
  fn.img = urls.ubuntuIconsGhp + fn.join('/');
  return '[![' + fn[1] + '](' + fn.img + ')](' + fn.img + ') ';
}

sortedKeys(data).forEach(function (categName) {
  var stocks = data[categName];
  categName = String(categName || 'uncategorized');
  cl(categName);
  cl(categName.replace(/[\S\s]/g, '-'));
  cl('| GTK_STOCK_… | PyGTK | Ubuntu | en_US | de_DE | Versions |');
  cl('|:-----       |:-----:| :----: |:----- |:----- |  :----:  |');
  sortedKeys(stocks).forEach(function (stockName) {
    var stockItem = stocks[stockName], pyGtkIcon = '', ubuntuIcon,
      gtkVersions;
    gtkVersions = (stockItem.gnome_dev_since || '?') + ' – ' +
      (stockItem.gnome_dev_deprecated || '+');
    pyGtkIcon += pyGtkWebIcon(stockItem.pygtk_docs_icon);
    pyGtkIcon += pyGtkWebIcon(stockItem.pygtk_docs_icon_rtl, ' RTL');
    ubuntuIcon = ubuntuWebIcon(stockItem.iconfile_pygtk);
    cl(['', stockName, (pyGtkIcon || cellNone), (ubuntuIcon || cellNone),
      relabel(stockName, stockItem, 'en_US'),
      relabel(stockName, stockItem, 'de_DE'),
      gtkVersions,
      ''].join(' | ').replace(/ *(^| |$) */g, '$1'));
  });
  cl('');
});

cl('Image credits');
cl('-------------');
cl(' * PyGTK icons: from [the docs](' + urls.pyGtkDoc + ') in good faith',
  "because I couldn't find a copyright notice there.");
['Humanity', 'Gnome'].forEach(function (theme) {
  cl(' *', theme, 'icons: see [the repo](' + urls.ubuntuIconsRepo +
    theme.toLowerCase() + ') for authors and license.');
});














/*scroll*/
