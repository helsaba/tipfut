# -*- coding: utf-8 -*-

require 'bundler'
Bundler.require

root = File.dirname(__FILE__)
$:.unshift File.join(root, 'lib')

require 'tipcryptcurrency'

TipCryptCurrency::Database.connect
TipCryptCurrency::Database.upgrade!

app = TipCryptCurrency::Application.new
#begin
  app.run
#rescue Exception => e
#  retry
#end
