# coding: utf-8

=begin

Throwrin bot v0.01
Based on Tipmona bot v0.01

- Donation (for Tipmona) welcome -
  BTC: 15bi3u4pFxBA3fMrsXsNn645igW7xSJmny
  LTC: Ld5ojxT92egBsa2nJiK6DdzBB1Hoh5r7o3
 MONA: MSEFCyitaSrTKgp4gdGPhMxxY5ZmBx9wbg

- Thank you for your support! -


MIT License (MIT)

Copyright (c) 2014 Palon http://rix.xii.jp/

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

APPEND: Copyright (c) 2014 MonacoEx.org (Fixes for RINGO)

=end

# そろそろきっちりクラスにしたい。


require './bitcoin_rpc.rb'
require './multi_io.rb'
require 'rubygems'
require 'net/https'
require 'twitter'
require 'oauth'
require 'json'
require 'active_record'
require 'bigdecimal'
require 'logger'
require 'yaml'
require 'digest/md5'

$faucet_userid='throwrin-2761034186'
$maintainer_screenname='MonacoEx'
$maintainer_userid='throwrin-2611149793'

ActiveRecord::Base.configurations = YAML.load_file('database.yml')
ActiveRecord::Base.establish_connection("production")

class User < ActiveRecord::Base
end

log_file = File.open("bot.log", "a")

$log = Logger.new(MultiIO.new(STDOUT, log_file), 5)

$last_faucet = Hash::new

$random = Random.new()

module TipCryptCurrency

  def dice(message)
    length = message.length
    if length < 1
      $log.warn("Dice called but array is null!")
      return ""
    elsif length == 1
      $log.warn("Dice called and only one!")
      return message
    end
    messageArrayIndex = $random.rand(length-1)
    $log.debug("Dice selected: " + messageArrayIndex.to_s)

    return message[messageArrayIndex]
  end


  def isjp(username)
    l = @client.user(username).lang
    $log.debug("User language: #{l}")

    if l.index("ja")
      return true
    else
      return false
    end
  end

  def post_tweet(text, statusid = false)
    begin
      if statusid
        @client.update(text, :in_reply_to_status_id => statusid)
      else
        @client.update(text)
      end
    rescue Timeout::Error, StandardError => exc
      $log.error("Error while posting: #{exc}: [text]#{text}")
    else
      $log.info("Posted: #{text}")
    end
  end

  def getps()
    return "。" * $random.rand(5)
  end

  def get_user(screen_name)
    user = User.where(:screen_name => screen_name).first
    if !user.blank?
      return user
    else
      $log.debug("Not found in DB, create...")
      user = User.create(
                         :screen_name => screen_name,
                         :donated => 0,
                         :affection => 50,
                         :give_at => 0,
                         :banned => 0
                         )
      return user
    end
  end

  class Bot
    include TipCryptCurrency

    def initialize
      @client = Twitter::Streaming::Client.new do |config|
        config.consumer_key        = ENV['TWITTER_API_KEY']
        config.consumer_secret     = ENV['TWITTER_API_SECRET']
        config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
        config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
      end

      coind_address = ENV['COIND_ADDRESS'] || '127.0.0.1'
      coind_rpcport = ENV['COIND_RPCPORT']
      coind_username = ENV['COIND_USERNAME']
      coind_password = ENV['COIND_PASSWORD']
      coind_url = "http://#{coind_username}:#{coind_password}@#{coind_address}:#{coind_rpcport}"
      @coind = BitcoinRPC.new(coind_url)
    end

    #ツイートなどを含むメッセージを受けたときの処理
    def on_tweet(status)
      if status.text.index("RT") || !status.text.index("QT") || status.user.screen_name == "throwrin"
        return
      end

      $log.info("Tweet from #{status.user.screen_name}: #{status.text}")

      return if !status.text.index("@throwrin")
      message = status.text.gsub(/@throwrin ?/, "")
      $log.info("Message: #{message}")

      username = status.user.screen_name
      idstr = status.user.id.to_s
      account = "throwrin-" + idstr
      old_account = "throwrin-" + username.downcase

      # 古いデータが残っていれば自動で移動
      old_balance = @coind.getbalance(old_account,6)
      if old_balance > 0
        $log.info("Old balance is active. moving...")
        @coind.move(old_account, account, old_balance)
      end

      to_status_id = status.id

      return if username == "throwrin"
      userdata = get_user(username)

      case message
      when /RT.*@.*/
        $log.debug("Retweet. Ignore.")
      when /giveme|give me/
        # 自動ツイート系対策（できてるか自信ない）
        if status.source =~ /(twittbot(\.net)?|EasyBotter|IFTTT|Twibow|MySweetBot|BotMaker|rakubo2|Stoome|twiroboJP|劣化コピー|ツイ助|makebot)/
          return
        end
        $log.info("-> Giving...")
        if userdata.banned
          $log.info("-> Banned user.")
          post_tweet("@#{username} faucet機能が停止されています。ご不明な点があれば@#{$maintainer_screenname}へご連絡ください。", to_status_id)
          return
        end
        # Tweet count
        if @client.user(username).statuses_count < 25
          $log.info("-> Not enough tweet!");
          if isjp(username)
            post_tweet(dice([
                             "@#{username} ごめんなさい、まだあなたのアカウントのツイート数が少なすぎるようです#{getps()} Twitterをもっと使ってからもう一度お願いします！"
                            ]), to_status_id)
          else
            post_tweet("@#{username} Your account hasn't much tweet#{getps()}", to_status_id)
          end
          return
        end

        r_need_time = @client.user(username).created_at + (24 * 60 * 60 * 14)
        if r_need_time > Time.now
          $log.info("-> Not enough account created time!");
          if isjp(username)
            post_tweet(dice([
                             "@#{username} ごめんなさい、まだあなたはアカウントを作成してから二週間以上経ってないみたいです#{getps()}"
                            ]), to_status_id)
          else
            post_tweet("@#{username} Your account must be created at more than 2 weeks ago#{getps()}", to_status_id)
          end
          return
        end

        amount = (10 + $random.rand(50).to_f) / 10
        $log.debug("Amount: #{amount}")

        if $last_faucet[username] == nil || $last_faucet[username] + (24 * 60 * 60) < Time.now
          fb = @coind.getbalance($faucet_userid)
          if fb < 1
            $log.info("-> Not enough faucet pot!")
            if isjp(username)
              post_tweet(dice([
                               "@#{username} ごめんなさい、配布用ポットの中身が足りません＞＜ @rin_faucetに送金してもらえると嬉しいですっ！",
                               "@#{username} ごめんなさい、配布用ポットにRINが入ってないみたいです＞＜ @rin_faucetに送金してもらえると嬉しいですっ！",
                               "@#{username} ごめんなさい、配布用ポットの中身がもうありません＞＜ @rin_faucetに送金してもらえると嬉しいですっ！",
                               "@#{username} ごめんなさい、配布用ポットの中身がないみたいですっ＞＜ @rin_faucetに送金してもらえると嬉しいですっ！"
                              ]), to_status_id)
            else
              post_tweet("@#{username} Sorry, there is no more RIN in faucet (><) Please tip to @rin_faucet#{getps()}", to_status_id)
            end
            return
          end

          @coind.move($faucet_userid, account, amount)
          $log.info("-> Done.")
          if isjp(username)
            post_tweet(dice([
                             "@#{username} さんに#{amount}Rinプレゼントっ！",
                             "@#{username} さんに#{amount}Rinをプレゼント！",
                             "@#{username} さんに#{amount}Rinをプレゼントしましたっ！",
                             "@#{username} さんに#{amount}Rinプレゼントしました！！"
                            ]), to_status_id)
          else
            post_tweet("Present for @#{username} -san! Sent #{amount}Rin!", to_status_id)
          end
          $last_faucet[username] = Time.now
        else
          $log.info("-> Already received in last 24 hours!")
          if isjp(username)
            post_tweet(dice([
                             "@#{username} まだ最後の配布から24時間経ってないようです・・・ごめんなさい！",
                             "@#{username} まだ最後の配布から24時間経ってないようです・・・・ごめんなさい！",
                             "@#{username} まだ最後の配布から24時間経ってないみたいです・・・ごめんなさい！",
                             "@#{username} まだ最後の配布から24時間経ってないみたいです・・・・ごめんなさい！"
                            ]), to_status_id)
          else
            post_tweet("@#{username} You have already received RIN in the last 24 hours#{getps()}", to_status_id)
          end
        end
      when /(Follow|follow|フォロー|ふぉろー)して/
        $log.info("Following #{username}...")
        $log.info("-> Followed.")
        post_tweet("@#{username} をフォローしました！", to_status_id)
      when /balance/
        $log.info("Check balance of #{username}...")
        balance = @coind.getbalance(account,6)
        all_balance = @coind.getbalance(account,0)
        $log.info("-> #{balance}RIN (all: #{all_balance}RIN)")
        if isjp(username)
          $log.debug("Rolling dice")
          begin
            status = dice([
                           "@#{username} さんの残高は #{balance} Rinです！ (confirm中残高との合計: #{all_balance} Rin)",
                           "@#{username} さんの残高は #{balance} Rinですよ！ (confirm中残高との合計: #{all_balance} Rin)",
                           "@#{username} さんのアカウントには #{balance} Rinあります！ (confirm中残高との合計: #{all_balance} Rin)",
                           "@#{username} さんのアカウントには #{balance} Rinありますよ！ (confirm中残高との合計: #{all_balance} Rin)",
                           "@#{username} さんの残高は #{balance} Rinですっ！ (confirm中残高との合計: #{all_balance} Rin)",
                           "@#{username} さんの残高は #{balance} Rinですよっ！ (confirm中残高との合計: #{all_balance} Rin)"
                          ])
            $log.debug("Send: @#{status}")
            post_tweet(status,to_status_id)
          rescue
            $log.error("#{exc}: [text]#{text}")
          end
        else
          post_tweet("@#{username} 's balance is #{balance} Rin#{getps()} (Total with confirming balance: #{all_balance} Rin)", to_status_id)
        end
      when /deposit/
        $log.info("Get deposit address of #{username}...")
        address = @coind.getaccountaddress(account)
        $log.info("-> #{account} = #{address}")
        if isjp(username)
          post_tweet(dice([
                           "@#{username} #{address} にRingoを送金してください！",
                           "@#{username} #{address} にRingoを送ってください！",
                           "@#{username} #{address} にRingoを送金してくださいっ！",
                           "@#{username} #{address} にRingoを送ってくださいっ！"
                          ]), to_status_id)
        else
          post_tweet("@#{username} Please send RIN to #{address}", to_status_id)
        end
      when /message( |　)(.*)/
        if username == $maintainer_screenname
          puts "get?"
          post_tweet("管理者からの伝言です！ 「" + $2 + "」")
        end
      when /(withdraw)( |　)+(([1-9]\d*|0)(\.\d+)?)( |　)+(R[a-zA-Z0-9]{26,33}) ?/
        $log.info("Withdraw...")
        amount = $3.to_f
        tax = 0.005
        total = amount + tax
        address = $7
        balance = @coind.getbalance(account,6)

        $log.info("-> Withdraw #{amount}Rin + #{tax}Rin from @#{username}(#{balance}Rin) to #{address}")

        if balance < total
          $log.info("-> Not enough RIN. (#{balance} < #{total})")
          if isjp(username)
            post_tweet(dice([
                             "@#{username} ごめんなさい、残高が足りないようです#{getps()} 引き出しには#{tax}Rinの手数料がかかることにも注意してください！ (現在#{balance}Rin)",
                             "@#{username} ごめんなさい、残高が足りません＞＜ 引き出しには#{tax}Rinの手数料がかかることにも注意してください！ (現在#{balance}Rin)",
                             "@#{username} ごめんなさい、残高が足りないみたいです#{getps()} 引き出しには#{tax}Rinの手数料がかかることにも注意してください！ (現在#{balance}Rin)"
                            ]),to_status_id)
          else
            post_tweet("@#{username} Not enough balance. Please note that required #{tax}Rin fee when withdraw#{getps()}(Balance:#{balance}Rin)", to_status_id)
          end
          return
        end

        validate = @coind.validateaddress(address)
        if !validate['isvalid']
          $log.info("-> Invalid address")
          if isjp(username)
            post_tweet("@#{username} ごめんなさい、アドレスが間違っているみたいです#{getps()}", to_status_id)
          else
            post_tweet("@#{username} Invalid address#{getps()}",to_status_id)
          end
          puts "Invalid address."
        end

        $log.info("-> Sending...")
        txid = @coind.sendfrom(account,address,amount)

        $log.info("-> Checking transaction...")
        tx = @coind.gettransaction(txid)

        if tx
          fee = tx['fee']
          $log.info("-> TX Fee: #{fee}")
        else
          fee = 0
          $log.info("-> No TX Fee.")
        end

        @coind.move(account,"taxpot",tax + fee)
        potsent = tax + fee
        $log.info("-> Fee sent to taxpot: #{potsent}Rin (Real fee: #{fee}Rin)")
        if isjp(username)
          post_tweet(dice([
                           "@#{username} Ringoを引き出しました！http://api.monaco-ex.org/abe/Ringo/tx/#{txid}",
                           "@#{username} さんのRingoを引き出しました！http://api.monaco-ex.org/abe/Ringo/tx/#{txid}",
                           "@#{username} Ringoを引き出しましたっ！http://api.monaco-ex.org/abe/Ringo/tx/#{txid}"
                          ]),to_status_id)
        else
          post_tweet("@#{username} Withdraw complete. http://api.monaco-ex.org/abe/Ringo/tx/#{txid}", to_status_id)
        end
      when /getcode/
        $log.info("Generate code...")
        inv_code = Digest::MD5.hexdigest(idstr)[0,10]
        post_tweet("@#{username} 招待コード: #{inv_code}", to_status_id)
        userdata.register_code = inv_code
        userdata.save
      when /(tip)( |　)+@([A-z0-9_]+)( |　)+(([1-9]\d*|0)(\.\d+)?)/
        $log.info("Sending...")

        balance = @coind.getbalance(account,6)
        from = username
        to = $3
        amount = $5.to_f

        $log.info("-> Send #{amount}rin from @#{from} to @#{to}")

        return if amount < 0


        if balance < amount
          $log.info("-> Not enough Rin. (#{balance} < #{amount})")
          if isjp(username)
            post_tweet(dice([
                             "@#{username} ごめんなさい、残高が足りないみたいです＞＜ 6confirmされるまで残高が追加されないことにも注意してください！(現在の残高:#{balance}Rin)",
                             "@#{username} ごめんなさい、残高が足りないみたいです・・・ 6confirmされるまで残高が追加されないことにも注意してください！(現在の残高:#{balance}Rin)",
                             "@#{username} ごめんなさい、残高が足りないようです＞＜ 6confirmされるまで残高が追加されないことにも注意してください！(現在の残高:#{balance}Rin)",
                             "@#{username} ごめんなさい、残高が足りないようですっ＞＜ 6confirmされるまで残高が追加されないことにも注意してください！(現在の残高:#{balance}Rin)",
                             "@#{username} ごめんなさい、残高が足りないようです・・ 6confirmされるまで残高が追加されないことにも注意してください！(現在の残高:#{balance}Rin)"
                            ]), to_status_id)
          else
            post_tweet("@#{username} Not enough balance. Please note that your balance apply when after 6 confirmed.#{getps()}(Balance:#{balance}Rin)", to_status_id)
          end
          return
        end

        begin
          to_userdata = @client.user(to)
        rescue Twitter::Error::NotFound
          post_tweet("@#{username} 申し訳ありません！#{to}というユーザー名は存在しないようです。", to_status_id)
          return
        end

        to_account = "throwrin-" + to_userdata.id.to_s
        @coind.move(account,to_account,amount)
        $log.info("-> Sent.")

        if to_account == "throwrin-28724542"
          userdata.affection = userdata.affection + (amount * 1).round
          post_tweet(dice([
                           "@#{from} 開発者への寄付ですね！ありがとうございます。",
                           "@#{from} 開発者への寄付、ありがとうございます。",
                           "@#{from} 開発へのご支援ありがとうございます！",
                           "@#{from} 開発のご支援ありがとうございます！"
                          ]), to_status_id)
          userdata.save
        elsif to_account == $faucet_userid
          userdata.donated = userdata.donated + amount
          userdata.affection = userdata.affection + (amount * 0.5).round
          userdata.save
          if amount > 5
            post_tweet(dice([
                             "@#{from} わぁ・・・こんなにたくさんありがとうございます！ #{amount}rinを寄付用ポットにお預かりしました！",
                             "@#{from} わぁ・・・こんなにたくさんありがとうございますっ！ #{amount}rinを寄付用ポットにお預かりしました！",
                             "@#{from} こんなにいいんですか！？ありがとうございます！ #{amount}rinを寄付用ポットにお預かりしました！",
                             "@#{from} こんなにいいんですか！？ありがとうございますっ！ #{amount}rinを寄付用ポットにお預かりしました！",
                             "@#{from} こんなにいっぱい・・・ありがとうございます！ #{amount}rinを寄付用ポットにお預かりしました！",
                             "@#{from} こんなにいっぱい・・・ありがとうございますっ！ #{amount}rinを寄付用ポットにお預かりしました！",
                             "@#{from} すごい・・・本当にありがとうございます！ #{amount}rinを寄付用ポットにお預かりしました！",
                             "@#{from} すごい・・・本当にありがとうございますっ！ #{amount}rinを寄付用ポットにお預かりしました！",
                             "@#{from} わぁ・・・ありがとうございます！大好きです！ #{amount}rinを寄付用ポットにお預かりしました！"
                            ]), to_status_id)
          else
            post_tweet(dice([
                             "@#{from} ありがとうございます！ #{amount}rinを寄付用ポットにお預かりしました！",
                             "@#{from} わー、ありがとうございます！ #{amount}rinを寄付用ポットにお預かりしました！",
                             "@#{from} ありがとうございます！ #{amount}rinを寄付用ポットにお預かりしました！",
                             "@#{from} わー、ありがとうございます！ #{amount}rinを寄付用ポットにお預かりしました！",
                             "@#{from} ありがとうございます！ #{amount}rinを寄付用ポットにお預かりしましたっ！",
                             "@#{from} わー、ありがとうございます！ #{amount}rinを寄付用ポットにお預かりしましたっ！",
                             "@#{from} ありがとうございます！ #{amount}rinを寄付用ポットにお預かりしましたっ！",
                             "@#{from} わー、ありがとうございます！ #{amount}rinを寄付用ポットにお預かりしましたっ！"
                            ]), to_status_id)
          end
        end
        if isjp(to)
          post_tweet(dice([
                           "@#{from} さんから @#{to} さんにお届け物ですっ！ つ[#{amount}rin]",
                           "@#{from} さんから @#{to} さんにお届け物ですよっ！ つ[#{amount}rin]",
                           "@#{from} さんから @#{to} さんにお届け物です！ つ[#{amount}rin]",
                           "@#{from} さんから @#{to} さんにお届け物ですよー！ つ[#{amount}rin]",
                           "@#{from} さんの#{amount}rinを @#{to} さんにどんどこわっしょーいっ",
                           "@#{from} さんの#{amount}rinを @#{to} さんにどんどこわっしょーい！",
                           "@#{from} さんの#{amount}rinを @#{to} さんにどんどこわっしょーいっ！"
                          ]), to_status_id)
        else
          post_tweet(dice([
                           "@#{from} -san to @#{to} -san! sent #{amount}rin.",
                           "From @#{from} -san to @#{to} -san! sent #{amount}rin.",
                           "@#{from} -san's #{amount}rin sent to @#{to} -san!"
                          ]),to_status_id)
        end
        # ネタ系統
      when /((結婚|けっこん|ケッコン))|marry ?me/
        if userdata.affection >= 500
          post_tweet(dice([
                           "@#{username} は、はい！",
                           "@#{username} 喜んで！"
                          ]), to_status_id)
        elsif userdata.affection >= 300
          post_tweet(dice([
                           "@#{username} そ、そんなこと言われても…///",
                           "@#{username} 考えさせてください。",
                           "@#{username} 少し考えさせてください。",
                           "@#{username} 考えさせてください…"
                          ]), to_status_id)
        elsif userdata.affection >= 100
          post_tweet(dice([
                           "@#{username} お気持ちは嬉しいですが、ごめんなさい…",
                           "@#{username} 嬉しいけど、ごめんなさい。"
                          ]), to_status_id)
        else
          post_tweet(dice([
                           "@#{username} ごめんなさい！",
                           "@#{username} ごめんなさい・・・"
                          ]), to_status_id)
        end
      when /info/
        post_tweet("@#{username} 寄付総額: #{userdata.donated} 好感度:#{userdata.affection}")
      end
    end

    def run
      @client.user do |object|
        case object
        when Twitter::Tweet
          on_tweet(object)
        end
      end
    end
  end
end


if __FILE__ == $0
  bot = TipCryptCurrency::Bot.new
  bot.run
end

