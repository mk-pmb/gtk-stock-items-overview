#!/usr/bin/python
# -*- coding: UTF-8, tab-width: 4 -*-

import gtk
from os import getenv
from json import dumps as jsonify

lang = getenv('LANGUAGE').split('.')[0]
labels = []

for stock_id in sorted(gtk.stock_list_ids()):
    info = gtk.stock_lookup(stock_id)
    if info is None:
        info = [stock_id, None, None, None, None]
    (id_again, label, accel_modifier, accel_keyval, translation_domain) = info
    if stock_id.startswith('gtk-'):
        stock_id = '_'.join(stock_id.split('-')[1:]).upper()
    labels.append(jsonify(stock_id) + ': { "label_' + lang
        + '": ' + jsonify(label) + ' }')

print '{ ' + ',\n  '.join(labels) + '\n}'
