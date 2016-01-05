$LOAD_PATH << '..'
require 'musikbot'

module StaleFilters
  def self.run
    @mb = MusikBot::Session.new(inspect)

    @report_page = 'User:MusikBot/StaleFilters/Report'
    @total_page = 'User:MusikBot/StaleFilters/Total'
    @offset_page = 'User:MusikBot/StaleFilters/Offset'

    generate_report
  rescue => e
    @mb.report_error('Fatal error', e)
  end

  def self.generate_report
    extended_content = "<div style='font-size:24px'>#{t(:title, date: I18n.l(@mb.today, format: :heading))}</div>\n" +
      t(:summary, num: stale_filters.length, days: offset) +
      "\n\n{| class='wikitable sortable'\n! " +
      [
        t('Filter'),
        t('Description'),
        t('Last hit'),
        t('Last filter author'),
        t('Last filter edit'),
        t('Private'),
        t('Actions')
      ].join("\n! ") + "\n|-\n"

    stale_filters.each do |filter|
      puts "#{index} of #{stale_filters.length}: #{title}" if @env == :test

      extended_content += '| ' + [
        "[[#{t('Special:AbuseFilter')}/#{filter['af_id']}|#{filter['af_id']}]]",
        filter['af_public_comments'].force_encoding('utf-8'),
        t(:plain_link, url: log(filter['af_id']), name: fdate(filter['afl_timestamp'])),
        t(:user_link, name: filter['af_user_text'].force_encoding('utf-8')),
        "[[#{history(filter['af_id'])}|#{fdate(filter['af_timestamp'])}]]",
        filter['af_hidden'] == 1 ? t('yes') : t('no'),
        translate(filter['af_actions'])
      ].join("\n| ") + "\n|-\n"
    end

    extended_content = extended_content.chomp("|-\n") + "|}\n\n"

    summary = t(:edit_summary, num: stale_filters.length)

    @mb.edit(@report_page,
      content: extended_content,
      summary: summary,
      bot: false
    )

    @mb.edit(@total_page,
      content: stale_filters.length,
      summary: summary
    )
  end

  # FIXME: use https://github.com/michaelfairley/method_decorators !!!!
  def self.stale_filters
    return @stale_filters if @stale_filters

    query = 'SELECT af_id, af_user_text, afl.afl_timestamp, af_timestamp, af_public_comments, af_hidden, af_actions ' \
      "FROM #{@mb.lang}wiki_p.abuse_filter af INNER JOIN (SELECT afl_id, afl_filter, MAX(afl_timestamp) afl_timestamp " \
      "FROM #{@mb.lang}wiki_p.abuse_filter_log GROUP BY afl_filter) afl ON afl.afl_filter = af_id " \
      "WHERE af_enabled = 1 AND af_deleted = 0 AND afl.afl_timestamp < #{offset_date};"

    @stale_filters = @mb.repl_client.query(query).to_a
  end

  def self.offset
    @offset ||= @mb.get(@offset_page).to_i
  end

  # Helpers
  def self.translate(str)
    str.split(',').map { |s| t(s) }.join(', ')
  end

  def self.offset_date
    @mb.db_date(@mb.today - offset)
  end

  def self.fdate(date)
    I18n.l(@mb.parse_date(date), format: :reporting)
  end

  def self.log_entry(id)
    "#{t('Special:AbuseLog')}/#{id}"
  end

  def self.history(id)
    "#{t('Special:AbuseFilter')}/history/#{id}"
  end

  def self.log(id)
    "//#{@mb.opts[:project]}.org/w/index.php?title=#{t('Special:AbuseLog')}&wpSearchFilter=#{id}"
  end
end

StaleFilters.run
