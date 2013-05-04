#!/usr/local/bin/ruby
# -*- coding: utf-8 -*-
require 'json'
require 'net/http'
require 'uri'
require 'date'

API_BASE = "api.flurry.com"
APIKEY = "KNSZ543WH8JJJWW38BRG"
APICODE = "89JCJTZYK5MHWKGTR452"

def createBasicMetricsAPIURL(startDate, endDate)
  "/eventMetrics/Summary?apiAccessCode="+APICODE+
    "&apiKey="+APIKEY+
    "&startDate="+startDate.to_s+
    "&endDate="+endDate.to_s
end

def createEventAPIURL(eventName,startDate, endDate)
  "/eventMetrics/Event?apiAccessCode="+APICODE+
    "&apiKey="+APIKEY+
    "&startDate="+startDate.to_s+
    "&endDate="+endDate.to_s+
    "&eventName="+eventName
end

def getRequest(url_str)
  url = URI.parse(url_str)
  if(url.query != nil)
          req = Net::HTTP::Get.new(url.path + "?" + url.query)
  else  
          req = Net::HTTP::Get.new(url.path)
  end
  res = Net::HTTP.start(url.host, url.port) {|http|
   http.request(req)
  }
  case res
  when Net::HTTPSuccess     then JSON.parse(res.body)
  when Net::HTTPRedirection then sleep 1; getRequest(res['location'])
  else
    res.error!
  end
  
end

def requestEventData(eventName, startDate, endDate)
  getRequest("http://"+API_BASE+createEventAPIURL(eventName, startDate, endDate))
end

def writeEvent1DataToFile(dataObj, filename)
  File.open(filename,"w") do |file|
    file.write("Name,UsersLastDay,UsersLastWeek,UsersLastMonth,AvgUsersLastDay,AvgUsersLastWeek,AvgUsersLastMonth,TotalCounts,TotalSessions\n");
    dataObj['event'].each do |event|
      file.write "#{event['@eventName']},#{event['@usersLastDay']},#{event['@usersLastWeek']},#{event['@usersLastMonth']}"+
        ",#{event['@avgUsersLastDay']},#{event['@avgUsersLastWeek']},#{event['@avgUsersLastMonth']},#{event['@totalCount']},#{event['@totalSessions']}\n"
    end
  end
end

def writeEvent2DataToFile(dataObj, filename)
  File.open(filename,"w") do |file|
    file.write("Event,UniqueUsers,TotalSessions,TotalCount\n")
    dataObj.each do |event|
      days = event['day']
      if (!days.instance_of?(Array))
        file.write "#{event['@eventName']},#{days['@uniqueUsers']},#{days['@totalSessions']},#{days['@totalCount']}\n"
      else
        days.each do |day|
          file.write "#{event['@eventName']},#{day['@uniqueUsers']},#{day['@totalSessions']},#{day['@totalCount']}\n"
        end
      end
    end
  end
end

def writeParameterDataToFile(dataobj, filename)
  File.open(filename, "w") do |file|
    file.write("Event,Parameter,Output,Count\n")
    dataobj.each do |event|
      parameters = event['parameters']
      if(parameters != nil)
        params = parameters['key']
        if(!params.instance_of?(Array))
          if(params['value'].instance_of?(Array))
            params['value'].each do |value|
              file.write("#{event['@eventName']},#{params['@name']},#{value['@name']},#{value['@totalCount']}\n")
            end
          else
             file.write("#{event['@eventName']},#{params['@name']},#{params['value']['@name']},#{params['value']['@totalCount']}\n")
          end
        else
          params.each do |param|
            if(param['value'].instance_of?(Array))
              param['value'].each do |value|
                file.write("#{event['@eventName']},#{param['@name']},#{value['@name']},#{value['@totalCount']}\n")
              end
            else
              file.write("#{event['@eventName']},#{param['@name']},#{param['value']['@name']},#{param['value']['@totalCount']}\n")
            end
          end
        end
      end
    end
  end
end

def requestData(startDate, endDate)
  getRequest("http://"+API_BASE+createBasicMetricsAPIURL(startDate, endDate))
end

def requestYesterdayData()
  res = requestData(Date.today-1, Date.today-1)
  writeEvent1DataToFile(res, "/var/www/html/flurry-logs/Event1/Event1_"+(Date.today-1).to_s+".csv");
  eventNames = res['event'].collect{|info|
    info['@eventName']
  }
  eventInfos = eventNames.collect{|eventName|
    sleep 1
    requestEventData(eventName, Date.today-1, Date.today-1)
  }
  writeEvent2DataToFile(eventInfos, "/var/www/html/flurry-logs/Event2/Event2_Daily_"+(Date.today-1).to_s+".csv")
  writeParameterDataToFile(eventInfos, "/var/www/html/flurry-logs/Parameter/Parameter_Daily_"+(Date.today-1).to_s+".csv")
end

def requestWeeklyData()
  res = requestData(Date.today-7, Date.today-1)
  eventNames = res['event'].collect{|info|
    info['@eventName']
  }
  eventInfos = eventNames.collect{|eventName|
    sleep 1
    requestEventData(eventName, Date.today-7, Date.today-1)
  }
  writeEvent2DataToFile(eventInfos, "/var/www/html/flurry-logs/Event2/Event2_Weekly_"+(Date.today-7).to_s+"_"+(Date.today-1).to_s+".csv")
  writeParameterDataToFile(eventInfos, "/var/www/html/flurry-logs/Parameter/Parameter_Weekly_"+(Date.today-7).to_s+"_"+(Date.today-1).to_s+".csv")
end

def requestMonthlyData()
  startDate = Date.today - 30
  endDate = Date.today - 1
  res = requestData(startDate, endDate)
  eventNames = res['event'].collect{|info|
    info['@eventName']
  }
  eventInfos = eventNames.collect{|eventName|
    sleep 1
    requestEventData(eventName, startDate, endDate)
  }
  writeEvent2DataToFile(eventInfos, "/var/www/html/flurry-logs/Event2/Event2_Monthly_"+startDate.to_s+"_"+endDate.to_s+".csv")
  writeParameterDataToFile(eventInfos, "/var/www/html/flurry-logs/Parameter/Parameter_Monthly_"+startDate.to_s+"_"+endDate.to_s+".csv")
end

def requestAllData()
  startDate = Date.new(2013, 5, 1)
  endDate = Date.today-1
  res = requestData(startDate, endDate)
  eventNames = res['event'].collect{|info|
    info['@eventName']
  }
  eventInfos = eventNames.collect{|eventName|
    sleep 1
    requestEventData(eventName, startDate, endDate)
  }
  writeEvent2DataToFile(eventInfos, "/var/www/html/flurry-logs/Event2/Event2_Total_"+endDate.to_s+".csv")
  writeParameterDataToFile(eventInfos, "/var/www/html/flurry-logs/Parameter/Parameter_Total_"+endDate.to_s+".csv")
end


def main()
  requestYesterdayData()
  sleep 1
  requestWeeklyData()
  sleep 1
  requestMonthlyData()
  sleep 1
  requestAllData()
end

main()

