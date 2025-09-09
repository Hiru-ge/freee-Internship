/**
 * freee API クライアント
 * 従業員情報、勤怠情報、事業所情報の取得・登録を担当
 */


function getRequestOptions(method, payload) {
  return {
    'method' : method || 'get',
    'muteHttpExceptions' : true,
    "contentType": "application/json",
    'headers' : {
      'accept': 'application/json',
      'Authorization': 'Bearer ' + accessToken
    },
    'payload' : payload
  }
}

function extractApiData(response, dataKey, errorContext) {
  var responseJson = JSON.parse(response.getContentText());
  
  if (response.getResponseCode() != 200) {
    console.error('APIエラー:', responseJson.message || '不明なエラー');
    console.error('レスポンスコード:', response.getResponseCode());
    console.error('レスポンス内容:', responseJson);
    return null;
  }
  
  var data = Array.isArray(responseJson) ? responseJson : responseJson[dataKey];
  
  if (!data) {
    console.error(errorContext + 'が取得できませんでした:', responseJson);
    return null;
  }
  
  return data;
}

function getCompanyName() {
  var requestUrl = 'https://api.freee.co.jp//api/1/companies/' + companyId.toString()
  var response = UrlFetchApp.fetch(requestUrl, getRequestOptions())
  var responseJson = JSON.parse(response.getContentText())
  if (response.getResponseCode() != 200) {
    console.error(responseJson.message)
    return responseJson.message
  }
  var companyName = responseJson.company.display_name
  return companyName
}

function getEmployees() {
  var requestUrl = 'https://api.freee.co.jp/hr/api/v1/companies/'
    + companyId.toString() 
    + '/employees?limit=50&with_no_payroll_calculation=true'
  var response = UrlFetchApp.fetch(requestUrl, getRequestOptions())
  
  var employees = extractApiData(response, 'employees', '従業員データ');
  if (!employees) {
    return [];
  }

  employees.sort(function(a, b) {
    return a.id - b.id;
  });

  return employees;
}

function getEmployee() {
  var selectedEmpId = PropertiesService.getUserProperties().getProperty('selectedEmpId')
  
  if (!selectedEmpId) {
    console.error('従業員IDが設定されていません');
    return null;
  }
  
  var now = new Date();
  var requestUrl = 'https://api.freee.co.jp/hr/api/v1/employees/'
    + selectedEmpId.toString()
    + '?company_id=' + companyId.toString()
    + '&year=' + now.getFullYear()
    + '&month=' + (now.getMonth() + 1)
  var response = UrlFetchApp.fetch(requestUrl, getRequestOptions())
  
  var employees = extractApiData(response, 'employee', '従業員データ');
  if (!employees) {
    console.error('従業員データの取得に失敗しました');
    return null;
  }
  
  var employee = Array.isArray(employees) ? employees[0] : employees;
  return employee;
}

function getTimeClocks() {
  var selectedEmpId = PropertiesService.getUserProperties().getProperty('selectedEmpId')
  var requestUrl = 'https://api.freee.co.jp/hr/api/v1/employees/'
    + selectedEmpId.toString()
    + '/time_clocks?company_id=' + companyId.toString()
  var response = UrlFetchApp.fetch(requestUrl, getRequestOptions())
  
  var timeClocks = extractApiData(response, 'time_clocks', '勤怠データ');
  if (!timeClocks) {
    return [];
  }

  var formattedRecords = []
  for (var clockIndex = 0; clockIndex <= timeClocks.length - 1; clockIndex++) {
    var timeClock = timeClocks[clockIndex]
    var type = timeClock['type']
    var datetime = timeClock['datetime']
    var dateObj = new Date(datetime)
    var dateStr = formatDateTimeJapanese(dateObj)

    var typeName = ''
    switch (type) {
      case 'clock_in':
        typeName = '出勤'
        break
      case 'break_begin':
        typeName = '休憩開始'
        break
      case 'break_end':
        typeName = '休憩終了'
        break
      case 'clock_out':
        typeName = '退勤'
        break;
    }
    formattedRecords.push({
      'date': dateStr,
      'type': typeName
    })
  }
  return formattedRecords
}

function getTimeClocksHistory(employeeId) {
  try {
    
    var now = new Date();
    var sixMonthsAgo = new Date(now.getFullYear(), now.getMonth() - 6, 1);
    
    // 6ヶ月前の日付を文字列にフォーマット
    var fromDate = sixMonthsAgo.getFullYear() + '-' 
      + String(sixMonthsAgo.getMonth() + 1).padStart(2, '0') + '-' 
      + String(sixMonthsAgo.getDate()).padStart(2, '0');
    
    // 現在の日付を文字列にフォーマット
    var toDate = now.getFullYear() + '-' 
      + String(now.getMonth() + 1).padStart(2, '0') + '-' 
      + String(now.getDate()).padStart(2, '0');
    
    
    var requestUrl = 'https://api.freee.co.jp/hr/api/v1/employees/'
      + employeeId.toString()
      + '/time_clocks?company_id=' + companyId.toString()
      + '&from_date=' + fromDate
      + '&to_date=' + toDate;
    
    
    var response = UrlFetchApp.fetch(requestUrl, getRequestOptions());
    
    var timeClocks = extractApiData(response, 'time_clocks', '勤怠履歴データ');
    
    if (!timeClocks) {
      return JSON.stringify({});
    }
    
    var monthlyHistory = {};
    
    for (var clockIndex = 0; clockIndex < timeClocks.length; clockIndex++) {
      var timeClock = timeClocks[clockIndex];
      var datetime = timeClock['datetime'];
      var dateObj = new Date(datetime);
      
      var yearMonth = dateObj.getFullYear() + '-' + String(dateObj.getMonth() + 1).padStart(2, '0');
      
      if (!monthlyHistory[yearMonth]) {
        monthlyHistory[yearMonth] = [];
      }
      
      var typeName = '';
      switch (timeClock['type']) {
        case 'clock_in':
          typeName = '出勤';
          break;
        case 'break_begin':
          typeName = '休憩開始';
          break;
        case 'break_end':
          typeName = '休憩終了';
          break;
        case 'clock_out':
          typeName = '退勤';
          break;
      }
      
      monthlyHistory[yearMonth].push({
        'date': formatDateTimeJapanese(dateObj),
        'type': typeName,
        'datetime': datetime,
        'rawType': timeClock['type']
      });
    }
    
    // 各月のデータを日付順でソート
    for (var month in monthlyHistory) {
      monthlyHistory[month].sort(function(a, b) {
        return new Date(a.datetime) - new Date(b.datetime);
      });
    }
    
    return JSON.stringify(monthlyHistory);
    
  } catch (error) {
    console.error('勤怠履歴取得中にエラーが発生しました:', error.message);
    return JSON.stringify({});
  }
}

function getTimeClocksForMonth(employeeId, yearMonth) {
  try {
    
    var historyJson = getTimeClocksHistory(employeeId);
    
    var monthlyHistory = JSON.parse(historyJson);
    
    if (monthlyHistory[yearMonth]) {
      return JSON.stringify(monthlyHistory[yearMonth]);
    } else {
      return JSON.stringify([]);
    }
  } catch (error) {
    console.error('月別勤怠履歴取得中にエラーが発生しました:', error.message);
    return JSON.stringify([]);
  }
}

function getAvailableMonths(employeeId) {
  try {
    var historyJson = getTimeClocksHistory(employeeId);
    var monthlyHistory = JSON.parse(historyJson);
    
    var availableMonths = [];
    for (var yearMonth in monthlyHistory) {
      if (monthlyHistory[yearMonth].length > 0) {
        availableMonths.push({
          yearMonth: yearMonth,
          displayName: formatYearMonth(yearMonth),
          recordCount: monthlyHistory[yearMonth].length
        });
      }
    }
    
    // 年月順でソート（新しい順）
    availableMonths.sort(function(a, b) {
      return b.yearMonth.localeCompare(a.yearMonth);
    });
    
    return JSON.stringify(availableMonths);
  } catch (error) {
    console.error('利用可能月一覧取得中にエラーが発生しました:', error.message);
    return JSON.stringify([]);
  }
}

function postWorkRecord(form) {
  // ※デバッグするには以下の変数を直接書き換える必要があります
  var selectedEmpId = PropertiesService.getUserProperties().getProperty('selectedEmpId')
  // inputタグのnameで取得
  var targetDate = form.target_date
  var targetTime = form.target_time
  var targetType = form.target_type

  var requestPayload = {
      'company_id': companyId,
      'type': targetType,
      'date': 'string',
      'datetime': targetDate + ' ' + targetTime
  }
  var requestUrl = 'https://api.freee.co.jp/hr/api/v1/employees/'
    + selectedEmpId.toString()
    + '/time_clocks'
  var requestOptions = getRequestOptions('post', JSON.stringify(requestPayload))
  var response = UrlFetchApp.fetch(requestUrl, requestOptions)
  var responseJson = JSON.parse(response.getContentText())
  var responseCode = response.getResponseCode()
  if (responseCode != 201) {
    console.error(responseJson)
    return responseJson.message
  }
  return '登録しました'
}

function getTimeClocksFor(employeeId, dateObj) {
  var y = dateObj.getFullYear();
  var m = dateObj.getMonth() + 1;
  var d = dateObj.getDate();
  // 月と日を2桁にフォーマット（例: 8 → "08", 5 → "05"）
  var mStr = m < 10 ? '0' + m : String(m);
  var dStr = d < 10 ? '0' + d : String(d);
  var dateStr = y + '-' + mStr + '-' + dStr;

  var requestUrl = 'https://api.freee.co.jp/hr/api/v1/employees/' +
                   String(employeeId) +
                   '/time_clocks?company_id=' + companyId +
                   '&from_date=' + dateStr + '&to_date=' + dateStr;
                   
  var response = UrlFetchApp.fetch(requestUrl, getRequestOptions());
  
  var timeClocks = extractApiData(response, null, "勤怠情報");
  if (!timeClocks) {
    return [];
  }
  return timeClocks;
}

function getHourlyWage(employeeId) {
  try {
    // freee APIから基本時給を取得
    var requestUrl = 'https://api.freee.co.jp/hr/api/v1/employees/' 
      + employeeId.toString() 
      + '/basic_pay_rule?company_id=' + companyId.toString()
      + '&year=' + new Date().getFullYear() 
      + '&month=' + (new Date().getMonth() + 1);
    
    var response = UrlFetchApp.fetch(requestUrl, getRequestOptions());
    var responseJson = JSON.parse(response.getContentText());
    
    if (response.getResponseCode() === 200 && responseJson.employee_basic_pay_rule) {
      var payAmount = responseJson.employee_basic_pay_rule.pay_amount;
      if (payAmount && payAmount > 0) {
        return payAmount;
      }
    }
    
    // API取得に失敗した場合はデフォルト値を返す
    console.error('基本時給の取得に失敗しました。従業員ID:', employeeId, 'レスポンス:', responseJson);
    return 1000; // デフォルト時給1000円
    
  } catch (error) {
    // エラー時はデフォルト値を返す
    console.error('基本時給取得中にエラーが発生しました:', error.message);
    return 1000; // デフォルト時給1000円
  }
}
