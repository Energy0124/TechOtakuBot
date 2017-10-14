class TelegramWebhooksController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::MessageContext
  context_to_action!
  before_action :config


  def start(*)
    respond_with :message, text: t('.content')
  end

  def help(*)
    respond_with :message, text: t('.content')
  end

  def hb(*)
    today = Date.today
    # stupid hardcode, but anyway :P
    bd ={
        york: Date.new(today.year, 10, 15),
        lung: Date.new(today.year, 10, 28),
        nick: Date.new(today.year, 12, 2),
    }
    hb_img ='http://i0.kym-cdn.com/photos/images/facebook/000/115/357/portal-cake.jpg'
    case Date.today
      when bd[:york]
          respond_with :document , document: "https://i.imgur.com/NI6e6FF.gif", caption: t('.york')
      when bd[:lung]
          respond_with :document , document: "https://i.imgur.com/NI6e6FF.gif", caption: t('.lung')
      when bd[:nick]
          respond_with :document , document: "https://i.imgur.com/NI6e6FF.gif", caption: t('.nick')
      else
        respond_with :photo, photo: hb_img, caption: t('.else')
    end
  end

  def moegirl_api(*args)
    if args.any?
      term=args.first
    end
    client = MediawikiApi::Client.new "https://zh.moegirl.org/api.php"
    response = client.action :parse, page: term, section: 0, uft8: 1, redirects: 1, prop: %w(text)
    puts response.data
    html_doc = Nokogiri::HTML(response.data['text']['*'])
    summary = ''
    html_doc.css('p:first-of-type').each do |p|
      summary = p.content
      break
    end
    # respond_with :message, text: summary
    img_link=''
    html_doc.css('table > tr:nth-child(1) > td > span > a > img').each do |img|
      puts img
      img_link = img['src']
      break
    end
    unless img_link.empty? and summary.empty?
      respond_with :photo, photo: img_link, caption: summary
    end


  end

  def moegirl(*term)

    if term.any?
      term = term.join('_')

    else
      term = 'Special:随机页面'
    end
    puts term

    img_link, summary = get_moe_girl_info(term)

    if img_link.empty? or summary.empty?
      if img_link.empty? and not summary.empty?
        respond_with :message, text: summary

      else
        if summary.empty? and img_link.empty?
          respond_with :photo, photo: 'https://img.moegirl.org/common/1/1a/%E5%AF%BF%E5%8F%B8%E8%90%8C%E7%99%BE%E5%A8%98.png', caption: t('.missing')
        else
          respond_with :photo, photo: img_link, caption: summary

        end
      end


    else
      puts img_link.empty?, summary
      respond_with :photo, photo: img_link, caption: summary

    end
  end

  def miku(*)
    hb_img ='http://img1.ak.crunchyroll.com/i/spire2/c2a696f5add89d039eedfefd77922fbf1492087485_full.jpg'
    miku_img ='http://orig02.deviantart.net/54bb/f/2014/241/6/5/jpg_by_leek_s-d7x58ff.png'
    bd= Date.new 2007, 8, 31
    if Date.today.day.equal? bd.day and Date.today.month.equal? bd.month
      respond_with :photo, photo: hb_img, caption: t('.hb')
    else
      respond_with :photo, photo: miku_img, caption: t('.mikumikumi')

    end

  end

  def youtube(*keyword)
    if keyword.any?
      keyword = keyword.join ' '
    else
      keyword = 'miku'

    end

    videos = Yt::Collections::Videos.new
    video =videos.where(q: keyword, order: 'relevance').first
    respond_with :message, text: "https://www.youtube.com/watch?v=#{video.id}"


  end

  def memo(*args)
    if args.any?
      session[:memo] = args.join(' ')
      respond_with :message, text: t('.notice')
    else
      respond_with :message, text: t('.prompt')
      save_context :memo
    end
  end

  def remind_me
    to_remind = session.delete(:memo)
    reply = to_remind || t('.nothing')
    respond_with :message, text: reply
  end

  def keyboard(value = nil, *)
    if value
      respond_with :message, text: t('.selected', value: value)
    else
      save_context :keyboard
      respond_with :message, text: t('.prompt'), reply_markup: {
          keyboard: [t('.buttons')],
          resize_keyboard: true,
          one_time_keyboard: true,
          selective: true,
      }
    end
  end

  def inline_keyboard
    respond_with :message, text: t('.prompt'), reply_markup: {
        inline_keyboard: [
            [
                {text: t('.alert'), callback_data: 'alert'},
                {text: t('.no_alert'), callback_data: 'no_alert'},
            ],
            [{text: t('.repo'), url: 'https://github.com/telegram-bot-rb/telegram-bot'}],
        ],
    }
  end

  def callback_query(data)
    if data == 'alert'
      answer_callback_query t('.alert'), show_alert: true
    else
      answer_callback_query t('.no_alert')
    end
  end

  def message(message)
    respond_with :message, text: t('.content', text: message['text'])
  end

  def inline_query(query, offset)
    query = query.first(10) # it's just an example, don't use large queries.
    t_description = t('.description')
    t_content = t('.content')
    results = 5.times.map do |i|
      {
          type: :article,
          title: "#{query}-#{i}",
          id: "#{query}-#{i}",
          description: "#{t_description} #{i}",
          input_message_content: {
              message_text: "#{t_content} #{i}",
          },
      }
    end
    answer_inline_query results
  end

  # As there is no chat id in such requests, we can not respond instantly.
  # So we just save the result_id, and it's available then with `/last_chosen_inline_result`.
  def chosen_inline_result(result_id, query)
    session[:last_chosen_inline_result] = result_id
  end

  def last_chosen_inline_result
    result_id = session[:last_chosen_inline_result]
    if result_id
      respond_with :message, text: t('.selected', result_id: result_id)
    else
      respond_with :message, text: t('.prompt')
    end
  end

  def action_missing(action, *_args)
    if command?
      respond_with :message, text: t('telegram_webhooks.action_missing.command', command: action)
    else
      respond_with :message, text: t('telegram_webhooks.action_missing.feature', action: action)
    end
  end

  private

  def get_moe_girl_info(term)
    encoded_term = URI.encode term

    begin
      html_doc = Nokogiri::HTML(open("https://zh.moegirl.org/zh-hant/#{encoded_term}"))
      summary = ''
      html_doc.css('#mw-content-text > p').each do |p|
        puts p
        summary = p.content
        break
      end

      # respond_with :message, text: summary
      img_link=''
      html_doc.css('#mw-content-text > div.infotemplatebox > table > tr:nth-child(1) > td > span > a > img').each do |img|
        puts img
        img_link = img['src']
        break
      end
      if img_link.strip.chomp.empty?
        puts 'try another way'
        html_doc.css('#mw-content-text table img').each do |img|
          puts img
          img_link = img['src']
          break
        end
      end
      return img_link.strip.chomp, summary.strip.chomp
    rescue OpenURI::HTTPError => e
      if e.message == '404 Not Found'
        # handle 404 error
        return '', ''
      else
        raise e
      end
    end
  end


  private
  def config
    Yt.configure do |config|
      config.api_key = Rails.application.secrets.google['token']
      config.log_level = :debug
    end
  end
end


