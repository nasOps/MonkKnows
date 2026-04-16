# frozen_string_literal: true

class Page < ActiveRecord::Base
  # Map ISO language codes to PostgreSQL text search configurations
  PG_TEXT_SEARCH_CONFIG = {
    'en' => 'english',
    'da' => 'danish',
    'de' => 'german',
    'fr' => 'french',
    'es' => 'spanish'
  }.freeze

  # Full-text search — uses PostgreSQL tsvector in prod/dev, SQLite FTS5 in test
  def self.search(query, language: 'en')
    return none if query.nil? || query.strip.empty?

    if connection.adapter_name == 'PostgreSQL'
      search_tsvector(query, language)
    else
      search_fts5(query, language)
    end
  end

  # PostgreSQL: native full-text search via tsvector column
  def self.search_tsvector(query, language)
    pg_lang = PG_TEXT_SEARCH_CONFIG.fetch(language, 'english')
    where(language: language)
      .where('tsv @@ plainto_tsquery(?, ?)', pg_lang, query)
      .order(Arel.sql("ts_rank(tsv, plainto_tsquery(#{connection.quote(pg_lang)}, #{connection.quote(query)})) DESC"))
  end

  # SQLite: FTS5 virtual table (used in tests)
  def self.search_fts5(query, language)
    sanitized = query.gsub(/[?*"()^+\-:{}~]/, ' ').gsub(/\s+/, ' ').strip
    return none if sanitized.empty?

    joins('INNER JOIN pages_fts ON pages.rowid = pages_fts.rowid')
      .where(language: language)
      .where('pages_fts MATCH ?', sanitized)
      .order(Arel.sql('pages_fts.rank'))
  end
end
