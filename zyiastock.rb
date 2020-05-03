#!/usr/bin/env ruby

require 'nokogiri'
require 'open-uri'

products = {}
baseurl = 'https://www.myzyia.com/ADENA/shop/catalog.aspx'

now = Time.new.to_i
page = 0

loop do
  #break if page > 0
  begin
    content = open(baseurl, "Cookie" => "IntegralDist_177_Search=category=View All&search=&pageIndex=#{page}")
  rescue HTTPError => e
    puts "#{e}, retrying..."
    sleep(1)
    retry
  end

  doc = Nokogiri::HTML(content)
  items_block = doc.xpath('.//div[@id="MasterContentBody1_PageContent_ShopCatalog_Lister_pnlItems"]')
  rows = items_block.xpath('.//div[@class="row"]')
  page += 1

  if rows.length == 1
    break if /no items/.match(rows.xpath('.//span[@class="control-label"]').text)
  end

  puts "Page #{page}, total items: #{products.length}"

  rows.each do |r|
    items = r.xpath('.//div[contains(@id,"ctl00_ctl00_MasterContentBody1_PageContent_ShopCatalog_Lister_ItemListView_")]')

    items.each do |i|

      begin
        item_code = /Item Code: (\S+)/.match(i.at_xpath('.//div[@class="pro_sku"]').text)[1]
      rescue NoMethodError
        puts i.at_xpath('.//div[@class="pro_sku"]').text
      end


      if products.key?(item_code)
        puts "!!! Non-unique item code: #{item_code}"
        puts "Prev: #{products[item_code][:descr]} #{products[item_code][:price]}"
        puts "New:  #{i.at_xpath('.//div[@class="prod_description"]').text} #{i.at_xpath('.//div[@class="cart_price"]').text}"
      end

      products[item_code] = {
        :item_page => /window\.location\.assign\('([^']+)'\);/.match(i.attribute('onclick'))[1],
        :descr => i.at_xpath('.//div[@class="prod_description"]').text,
        :price => i.at_xpath('.//div[@class="cart_price"]').text.gsub(/Price:\S*/, ''),
      }
    end
  end
end

descr_width = 0
price_width = 0
count = 0
products.each_pair do |item, info|
  url = baseurl.gsub(/\/[^\/]+$/, '/') + info[:item_page]

  begin
    content = open(url) #, "Cookie" => "IntegralDist_177_Search=category=View All&search=&pageIndex=#{page}")
  rescue HTTPError => e
    puts "#{e}, retrying..."
    sleep(1)
    retry
  end

  doc = Nokogiri::HTML(content)
  
  products[item][:sizes] = []
  doc.xpath('//select[@id="ddl_choice_1"]').xpath('.//option').each do |s|
    products[item][:sizes] << s.text unless /Select Choice/.match(s.text)
  end

  descr_width = info[:descr].length if info[:descr].length > descr_width
  price_width = info[:price].length if info[:price].length > price_width

  count += 1
  print "Loading sizing info #{count}/#{products.length}\r"
  #puts "#{info[:descr]}; #{info[:price]}; #{info[:sizes].join(',')}"
end

file = "zyia-inventory-#{now}.txt"
puts "Writing inventory to #{file}"
File.open(file, 'w') do |f|
  products.each_pair do |item, info|
    f.write "#{info[:descr].ljust(descr_width + 5)}#{info[:price].ljust(price_width + 5)}Sizes: #{info[:sizes].join(', ')}\n"
  end
end
