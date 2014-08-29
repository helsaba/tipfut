# -*- coding: utf-8 -*-

module TipCryptCurrency
  class Database
    def self.connect
      DataMapper.finalize
      DataMapper.setup :default, ENV['DATABASE_URL']
      self
    end

    def self.migrate!
      DataMapper.auto_migrate!
    end

    def self.upgrade!
      DataMapper.auto_upgrade!
    end
  end
end
