#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'
require 'wikidata_ids_decorator'

def scraper(h)
  url, klass = h.to_a.first
  klass.new(response: Scraped::Request.new(url: url).response)
end

class MemberList < Scraped::HTML
  decorator WikidataIdsDecorator::Links

  field :members do
    member_rows.map { |tr| fragment(tr => MemberRow).to_h }
  end

  private

  def members_table
    noko.xpath('//h2[span[text()="Μέλη της Βουλής των Ελλήνων"]]/following-sibling::table[1]')
  end

  def member_rows
    members_table.xpath('.//tr[td]')
  end
end

class MemberRow < Scraped::HTML
  field :id do
    td[0].css('a').map { |a| a.attr('wikidata') }.compact.first
  end

  field :name do
    member_a.text.tidy
  end

  field :area_id do
    district_a&.attr('wikidata')
  end

  field :area do
    district_a&.text&.tidy
  end

  field :party_id do
    party_a&.attr('wikidata')
  end

  field :party do
    party_a&.text&.tidy
  end

  private

  def td
    noko.css('td')
  end

  def member_a
    td[0].css('a').first
  end

  def district_a
    td[1].css('a').first
  end

  def party_a
    td[3].css('a').first
  end
end

url = URI.encode 'https://el.wikipedia.org/wiki/Κατάλογος_Ελλήνων_βουλευτών_(Σεπτέμβριος_2015)'

data = scraper(url => MemberList).members
data.each { |mem| puts mem.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h } if ENV['MORPH_DEBUG']

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
ScraperWiki.save_sqlite(%i[name party], data)
