# -*- coding: utf-8 -*-

require 'data_mapper'

module TipCryptCurrency
  class Users
    include DataMapper::Resource

    property :id, Serial
    property :screen_name, String, :required => true
    property :donated,     Float, :default => 0
    property :affection,   Integer, :default => 50
    property :give_at,     Integer, :default => 0
    property :banned,      Boolean, :default => 0
  end
end
