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

require './bitcoin_rpc.rb'

module TipCryptCurrency

  def dice(message)
    length = message.length
    if length < 1
      return ""
    elsif length == 1
      return message[0]
    end
    messageArrayIndex = rand(length-1)
    @log.debug("Dice selected: " + messageArrayIndex.to_s)

    return message[messageArrayIndex]
  end


  def isjp(username)
    l = @twitter.user(username).lang
    @log.debug("User language: #{l}")

    if l.index("ja")
      return true
    else
      return false
    end
  end

  def post_tweet(text, statusid = false)
    begin
      if statusid
        @twitter.update(text, :in_reply_to_status_id => statusid)
      else
        @twitter.update(text)
      end
    rescue Timeout::Error, StandardError => exc
      @log.error("Error while posting: #{exc}: [text]#{text}")
    else
      @log.info("Posted: #{text}")
    end
  end

  def getps()
    return "。" * rand(5)
  end

  def get_user(screen_name)
    Users.first_or_create(:screen_name => screen_name)
  end

  class Application
    include TipCryptCurrency

    def initialize
      @log = Logger.new(STDERR)

      @twitter = Twitter::REST::Client.new do |config|
        config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
        config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
        config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
        config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
      end
      @twitter.update("Zzz.... (=_=)....")

      @config = YAML.load_file('config.yml')
      @faucet_userid = "#{@config['global']['account_prefix']}-#{@config['twitter']['faucet']['userid']}"

      coind_address = ENV['COIND_ADDRESS'] || '127.0.0.1'
      coind_rpcport = ENV['COIND_RPCPORT']
      coind_username = ENV['COIND_USERNAME']
      coind_password = ENV['COIND_PASSWORD']
      coind_url = "http://#{coind_username}:#{coind_password}@#{coind_address}:#{coind_rpcport}"
      @coind = BitcoinRPC.new(coind_url)

      @twitter.update("ふわわ・・・" + dice(["うたたね", "仮眠", "気絶"]) + "していました　お仕事、始めまーす。")
    end

    def upgrade_balance(old_account, account)
      old_balance = @coind.getbalance(old_account,6)
      if old_balance > 0
        @log.info("Found the old balance. moving...")
        @coind.move(old_account, account, old_balance)
      end
    end

    #ツイートなどを含むメッセージを受けたときの処理
    def on_tweet(status)
      if status.text.index("RT") || status.text.index("QT") || status.user.screen_name == @config['twitter']['tipbot']['screen_name']
        @log.debug("Ignored tweet from #{status.user.screen_name}: #{status.text}")
        return
      end

      @log.info("Tweet from #{status.user.screen_name}: #{status.text}")

      return if !status.text.index("@#{@config['twitter']['tipbot']['screen_name']}")
      message = status.text.gsub(/@#{@config['twitter']['tipbot']['screen_name']} ?/, "")
      @log.info("Message: #{message}")

      username = status.user.screen_name
      idstr = status.user.id.to_s
      account = "#{@config['global']['account_prefix']}-#{idstr}"
      old_account = "#{@config['global']['account_prefix']}-#{username.downcase}"

      upgrade_balance(old_account, account)

      to_status_id = status.id

      userdata = get_user(username)

      case message
      when /RT.*@.*/
        @log.debug("Retweet. Ignore.")
      when /giveme|give me/
        # 自動ツイート系対策（できてるか自信ない）
        if status.source =~ /(twittbot(\.net)?|EasyBotter|IFTTT|Twibow|MySweetBot|BotMaker|rakubo2|Stoome|twiroboJP|劣化コピー|ツイ助|makebot)/
          return
        end

        @log.info("-> Giving...")

        if userdata.banned
          @log.info("-> Banned user.")
          post_tweet("@#{username} faucet機能が停止されています。ご不明な点があれば @#{@config['twitter']['maintainer']['screen_name']} へご連絡ください。", to_status_id)
          return
        end

        if @twitter.user(username).statuses_count < 10
          @log.info("-> Not enough tweet!");
          if isjp(username)
            status = dice([
                           "ごめんなさい、まだあなたのアカウントのツイート数が少なすぎるようです#{getps()} Twitterをもっと使ってからもう一度お願いします！"
                          ])
          else
            status = "Your account hasn't much tweet#{getps()}"
          end

          post_tweet("@#{username} #{status}", to_status_id)
          return
        end

        r_need_time = @twitter.user(username).created_at + (24 * 60 * 60 * 14)
        if r_need_time > Time.now
          @log.info("-> Not enough account created time!");
          if isjp(username)
            status = dice([
                           "ごめんなさい、まだあなたはアカウントを作成してから二週間以上経ってないみたいです#{getps()}"
                          ])
          else
            status = "Your account must be created at more than 2 weeks ago#{getps()}"
          end

          post_tweet("@#{username} #{status}", to_status_id)
          return
        end

        amount = (10 + rand(50).to_f) / 10
        @log.debug("Amount: #{amount}")

        if $last_faucet[username] == nil || $last_faucet[username] + (24 * 60 * 60) < Time.now
          fb = @coind.getbalance(@faucet_userid)
          if fb < 0
            @coind.move(@faucet_userid, account, amount)
            @log.info("-> Done.")
            if isjp(username)
              status = dice([
                             "#{amount}#{@config['coin']['unit']}プレゼントっ！",
                             "#{amount}#{@config['coin']['unit']}をプレゼント！",
                             "#{amount}#{@config['coin']['unit']}をプレゼントしましたっ！",
                             "#{amount}#{@config['coin']['unit']}プレゼントしました！！"
                            ])
            else
              post_tweet("Present for you! Sent #{amount}#{@config['coin']['unit']}!", to_status_id)
            end
            $last_faucet[username] = Time.now
          else
            @log.info("-> Not enough faucet pot!")
            faucet_screen_name = @twitter.user(@config['twitter']['faucet']['userid']).screen_name
            if isjp(username)
              status = dice([
                             "ごめんなさい、配布用ポットの中身が足りません＞＜ @#{faucet_screen_name}に送金してもらえると嬉しいですっ！",
                             "ごめんなさい、配布用ポットに#{@config['coin']['unit']}が入ってないみたいです＞＜ @#{faucet_screen_name}に送金してもらえると嬉しいですっ！",
                             "ごめんなさい、配布用ポットの中身がもうありません＞＜ @#{faucet_screen_name}に送金してもらえると嬉しいですっ！",
                             "ごめんなさい、配布用ポットの中身がないみたいですっ＞＜ @#{faucet_screen_name}に送金してもらえると嬉しいですっ！"
                            ])
            else
              post_tweet("@#{username} Sorry, there is no more #{@config['coin']['unit']} in faucet (><) Please tip to @#{faucet_screen_name}#{getps()}", to_status_id)
            end
          end
        else
          @log.info("-> Already received in last 24 hours!")
          if isjp(username)
            status = dice([
                             "まだ最後の配布から24時間経ってないようです・・・ごめんなさい！",
                             "まだ最後の配布から24時間経ってないようです・・・・ごめんなさい！",
                             "まだ最後の配布から24時間経ってないみたいです・・・ごめんなさい！",
                             "まだ最後の配布から24時間経ってないみたいです・・・・ごめんなさい！"
                          ])
          else
            status = "You have already received #{@config['coin']['unit']} in the last 24 hours#{getps()}"
          end
        end
        post_tweet("@#{username} #{status}", to_status_id);
      when /(Follow|follow|フォロー|ふぉろー)(して|\s*me)/
        @log.info("Following #{username}...")
        @twitter.follow(username)
        @log.info("-> Followed.")
        post_tweet("@#{username} フォローしました！", to_status_id)
      when /balance/
        @log.info("Check balance of #{username}...")
        balance = @coind.getbalance(account,6)
        all_balance = @coind.getbalance(account,0)
        @log.info("-> #{balance}#{@config['coin']['unit']} (all: #{all_balance}#{@config['coin']['unit']})")
        if isjp(username)
          status = dice([
                         "残高は #{balance} #{@config['coin']['unit']}です！ (confirm中残高との合計: #{all_balance} #{@config['coin']['unit']})",
                         "残高は #{balance} #{@config['coin']['unit']}ですよ！ (confirm中残高との合計: #{all_balance} #{@config['coin']['unit']})",
                         "アカウントには #{balance} #{@config['coin']['unit']}あります！ (confirm中残高との合計: #{all_balance} #{@config['coin']['unit']})",
                         "アカウントには #{balance} #{@config['coin']['unit']}ありますよ！ (confirm中残高との合計: #{all_balance} #{@config['coin']['unit']})",
                         "残高は #{balance} #{@config['coin']['unit']}ですっ！ (confirm中残高との合計: #{all_balance} #{@config['coin']['unit']})",
                         "残高は #{balance} #{@config['coin']['unit']}ですよっ！ (confirm中残高との合計: #{all_balance} #{@config['coin']['unit']})"
                        ])
        else
          status = " balance is #{balance} #{@config['coin']['unit']}#{getps()} (total with confirming balance: #{all_balance} #{@config['coin']['unit']})"
        end
        @log.debug("Tweet: @#{status}")
        post_tweet("@#{username} #{status}", to_status_id)
      when /deposit/
        @log.info("Get deposit address of #{username}...")
        address = @coind.getaccountaddress(account)
        @log.info("-> #{account} = #{address}")
        if isjp(username)
          status = dice([
                         "#{address} に#{@config['coin']['name']}を送金してください！",
                         "#{address} に#{@config['coin']['name']}を送ってください！",
                         "#{address} に#{@config['coin']['name']}を送金してくださいっ！",
                         "#{address} に#{@config['coin']['name']}を送ってくださいっ！"
                        ])
        else
          status = " Please send #{@config['coin']['unit']} to #{address}"
        end
        post_tweet("@#{username} #{status}", to_status_id)
      when /message( |　)(.*)/
        if username == @config['twitter']['maintainer']['screen_name']
          puts "get?"
          post_tweet("管理者からの伝言です！ 「" + $2 + "」")
        end
      when /(withdraw)( |　)+(([1-9]\d*|0)(\.\d+)?)( |　)+(#{@config['coin']['address_prefix']}[a-zA-Z0-9]{26,33}) ?/
        @log.info("Withdraw...")
        amount = $3.to_f
        tax = 0.005
        total = amount + tax
        address = $7
        balance = @coind.getbalance(account,6)

        @log.info("-> Withdraw #{amount}#{@config['coin']['unit']} + #{tax}#{@config['coin']['unit']} from @#{username}(#{balance}#{@config['coin']['unit']}) to #{address}")

        if balance < total
          @log.info("-> Not enough #{@config['coin']['unit']}. (#{balance} < #{total})")
          if isjp(username)
            status = dice([
                           "ごめんなさい、残高が足りないようです#{getps()} 引き出しには#{tax}#{@config['coin']['unit']}の手数料がかかることにも注意してください！ (現在#{balance}#{@config['coin']['unit']})",
                           "ごめんなさい、残高が足りません＞＜ 引き出しには#{tax}#{@config['coin']['unit']}の手数料がかかることにも注意してください！ (現在#{balance}#{@config['coin']['unit']})",
                           "ごめんなさい、残高が足りないみたいです#{getps()} 引き出しには#{tax}#{@config['coin']['unit']}の手数料がかかることにも注意してください！ (現在#{balance}#{@config['coin']['unit']})"
                          ])
          else
            status = "Not enough balance. Please note that required #{tax}#{@config['coin']['unit']} fee when withdraw#{getps()}(Balance:#{balance}#{@config['coin']['unit']})"
          end
          post_tweet("@#{username} #{status}", to_status_id)
          return
        end

        validate = @coind.validateaddress(address)
        if !validate['isvalid']
          @log.info("-> Invalid address")
          if isjp(username)
            status = "ごめんなさい、アドレスが間違っているみたいです#{getps()}"
          else
            status = "Invalid address#{getps()}"
          end
          post_tweet("@#{username} #{status}", to_status_id)
        end

        @log.info("-> Sending...")
        txid = @coind.sendfrom(account,address,amount)

        @log.info("-> Checking transaction...")
        tx = @coind.gettransaction(txid)

        if tx
          fee = tx['fee']
          @log.info("-> TX Fee: #{fee}")
        else
          fee = 0
          @log.info("-> No TX Fee.")
        end

        @coind.move(account,"taxpot",tax + fee)
        potsent = tax + fee
        @log.info("-> Fee sent to taxpot: #{potsent}#{@config['coin']['unit']} (Real fee: #{fee}#{@config['coin']['unit']})")
        if isjp(username)
          status = dice([
                         "#{@config['coin']['name']}を引き出しました！",
                         "#{@config['coin']['name']}を引き出しましたっ！"
                        ])
        else
          status = "Withdraw complete."
        end
        post_tweet("@#{username} #{status} #{@config['global']['abe_url']}#{@config['coin']['name']}/tx/#{txid}", to_status_id)
      when /getcode/
        @log.info("Generate code...")
        inv_code = Digest::MD5.hexdigest(idstr)[0,10]
        post_tweet("@#{username} 招待コード: #{inv_code}", to_status_id)
        userdata.register_code = inv_code
        userdata.save
      when /(tip)( |　)+@([A-z0-9_]+)( |　)+(([1-9]\d*|0)(\.\d+)?)/

        to = $3
        amount = $5.to_f

        begin
          to_userdata = @twitter.user(to)
        rescue Twitter::Error::NotFound
          post_tweet("@#{username} 申し訳ありません！#{to}というユーザー名は存在しないようです。", to_status_id)
          return
        end

        @log.info("Sending...")

        balance = @coind.getbalance(account,6)
        from = username

        @log.info("-> Send #{amount}#{@config['coin']['unit']} from @#{from} to @#{to}")

        return if amount < 0


        if balance < amount
          @log.info("-> Not enough #{@config['coin']['unit']}. (#{balance} < #{amount})")
          if isjp(username)
            status = dice([
                           "ごめんなさい、残高が足りないみたいです＞＜",
                           "ごめんなさい、残高が足りないみたいです・・・",
                           "ごめんなさい、残高が足りないようです＞＜",
                           "ごめんなさい、残高が足りないようですっ＞＜",
                           "ごめんなさい、残高が足りないようです・・"]) +
              " 6confirmされるまで残高が追加されないことにも注意してください！(現在の残高:#{balance}#{@config['coin']['unit']})"

          else
            status = "Not enough balance. Please note that your balance apply when after 6 confirmed.#{getps()}(Balance:#{balance}#{@config['coin']['unit']})"
          end
          post_tweet("@#{username} #{status}", to_status_id)
          return
        end

        to_account = "#{@config['global']['account_prefix']}-#{to_userdata.id.to_s}"
        @coind.move(account,to_account,amount)
        @log.info("-> Sent to #{to_userdata.id.to_s}.")
@log.debug("#{@config['twitter']['faucet']['userid'].to_s == to_userdata.id.to_s}")
        if to_userdata.id.to_s == @config['twitter']['developer']['userid'].to_s
          userdata.affection = userdata.affection + (amount * 1).round
          post_tweet(dice([
                           "@#{from} 開発者への寄付ですね！ありがとうございます。",
                           "@#{from} 開発者への寄付、ありがとうございます。",
                           "@#{from} 開発へのご支援ありがとうございます！",
                           "@#{from} 開発のご支援ありがとうございます！"
                          ]), to_status_id)
          userdata.save
        elsif to_userdata.id.to_s == @config['twitter']['faucet']['userid'].to_s
          userdata.donated = userdata.donated + amount
          userdata.affection = userdata.affection + (amount * 0.5).round
          userdata.save
          if amount > 5
            status = dice([
                           "わぁ・・・こんなにたくさんありがとうございます！",
                           "わぁ・・・こんなにたくさんありがとうございますっ！",
                           "こんなにいいんですか！？ありがとうございます！",
                           "こんなにいいんですか！？ありがとうございますっ！",
                           "こんなにいっぱい・・・ありがとうございます！",
                           "こんなにいっぱい・・・ありがとうございますっ！",
                           "すごい・・・本当にありがとうございます！",
                           "すごい・・・本当にありがとうございますっ！",
                           "わぁ・・・ありがとうございます！大好きです！"
                            ])
          else
            status = dice([
                           "ありがとうございます！",
                           "わー、ありがとうございます！"
                          ])
          end
          status += " #{amount}#{@config['coin']['unit']}を寄付用ポットにお預かりしました！"
          post_tweet("@#{from} #{status}", to_status_id)
        end
        if isjp(to)
          status = dice([
                         "@#{from} さんから @#{to} さんにお届け物ですっ！ つ[#{amount}#{@config['coin']['unit']}]",
                         "@#{from} さんから @#{to} さんにお届け物ですよっ！ つ[#{amount}#{@config['coin']['unit']}]",
                         "@#{from} さんから @#{to} さんにお届け物です！ つ[#{amount}#{@config['coin']['unit']}]",
                         "@#{from} さんから @#{to} さんにお届け物ですよー！ つ[#{amount}#{@config['coin']['unit']}]",
                        ])
        else
          status = dice([
                         "@#{from} -san to @#{to} -san! sent #{amount}#{@config['coin']['unit']}.",
                         "From @#{from} -san to @#{to} -san! sent #{amount}#{@config['coin']['unit']}.",
                         "@#{from} -san's #{amount}#{@config['coin']['unit']} sent to @#{to} -san!"
                        ])
        end
        post_tweet(status, to_status_id)
        # ネタ系統
      when /((結婚|けっこん|ケッコン))|marry ?me/
        if userdata.affection >= 500
          status = dice([
                         "は、はい！",
                         "喜んで！"
                        ])
        elsif userdata.affection >= 300
          status = dice([
                         "そ、そんなこと言われても…///",
                         "考えさせてください。",
                         "少し考えさせてください。",
                         "考えさせてください…"
                        ])
        elsif userdata.affection >= 100
          status = dice([
                         "お気持ちは嬉しいですが、ごめんなさい…",
                         "嬉しいけど、ごめんなさい。"
                        ])
        else
          status = dice([
                         "ごめんなさい！",
                         "ごめんなさい・・・"
                        ])
        end
        post_tweet("@#{username} #{status}", to_status_id)
      when /info/
        post_tweet("@#{username} 寄付総額: #{userdata.donated} 好感度:#{userdata.affection}")
      end
    end

    def run
      @log.info('Start watching the user stream.')
      client = Twitter::Streaming::Client.new do |config|
        config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
        config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
        config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
        config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
      end

      client.user do |object|
        case object
        when Twitter::Tweet
          on_tweet(object)
        end
      end
    end
  end
end

