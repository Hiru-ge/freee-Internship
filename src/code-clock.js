/**
 * 打刻システム
 * 出勤・退勤打刻、打刻忘れチェックを担当
 */

function checkForgottenClockIns() {
  var now = new Date();
  var allShiftsJson = getShifts();
  if (!allShiftsJson) {
    return;
  }
  var allShifts = JSON.parse(allShiftsJson);
  var allEmployees = getEmployees();
  if (!allEmployees) {
    return;
  }

  var today = now.getDate();
  var currentHour = now.getHours();

  allEmployees.forEach(function(employee) {
    var employeeId = employee.id;
    var employeeShiftData = allShifts.shifts[employeeId];

    if (!employeeShiftData || !employeeShiftData.shifts || !employeeShiftData.shifts[today]) {
      return;
    }
    
    var shiftTime = employeeShiftData.shifts[today];
    var parsedShift = parseShiftTime(shiftTime);
    if (!parsedShift) {
      return;
    }
    var shiftStartHour = parsedShift.startHour;

    if (currentHour >= shiftStartHour && currentHour < shiftStartHour + 1) {
      var timeClocks = getTimeClocksFor(employeeId, now);
      var hasClockInToday = timeClocks.some(function(record) {
        return record.type === 'clock_in';
      });

      if (!hasClockInToday) {
        if (employee.email) {
          var subject = "【勤怠アラート】出勤打刻がされていません";
          var body = employee.display_name + "様\n\n" +
                     "本日のシフトの出勤打刻がまだ記録されていません。\n" +
                     "打刻忘れの場合は、速やかに打刻をお願いします。\n\n" +
                     "対象シフト: " + shiftTime;
          MailApp.sendEmail(employee.email, subject, body);
        }
      }
    }
  });
  
}

function checkForgottenClockOuts() {
  
  var now = new Date();
  var allShiftsJson = getShifts();
  if (!allShiftsJson) {
    return;
  }
  var allShifts = JSON.parse(allShiftsJson);
  var allEmployees = getEmployees();
  if (!allEmployees) {
    return;
  }

  var today = now.getDate();
  var currentHour = now.getHours();
  var currentMinute = now.getMinutes();

  allEmployees.forEach(function(employee) {
    var employeeId = employee.id;
    var employeeShiftData = allShifts.shifts[employeeId];

    if (!employeeShiftData || !employeeShiftData.shifts || !employeeShiftData.shifts[today]) {
      return;
    }
    
    var shiftTime = employeeShiftData.shifts[today];
    var parsedShift = parseShiftTime(shiftTime);
    if (!parsedShift) {
      return;
    }
    var shiftEndHour = parsedShift.endHour;

    if ((currentHour > shiftEndHour || (currentHour === shiftEndHour && currentMinute >= 0)) && 
        currentHour < shiftEndHour + 2) {
      
      var shouldSendReminder = (currentMinute % 15 === 0);
      
      if (shouldSendReminder) {
        var timeClocks = getTimeClocksFor(employeeId, now);
        var hasClockOutToday = timeClocks.some(function(record) {
          return record.type === 'clock_out';
        });

        if (!hasClockOutToday) {
          if (employee.email) {
            var subject = "【勤怠リマインダー】退勤打刻がされていません";
            var body = employee.display_name + "様\n\n" +
                       "本日のシフトの退勤打刻がまだ記録されていません。\n" +
                       "退勤打刻をお忘れなく！\n\n" +
                       "対象シフト: " + shiftTime + "\n" +
                       "退勤予定時刻: " + shiftEndHour + ":00";
            MailApp.sendEmail(employee.email, subject, body);
          }
        }
      }
    }
  });
  
}

function clockIn(employeeId) {
  try {
    
    var now = new Date();
    var dateStr = now.getFullYear() + '-' + 
                 String(now.getMonth() + 1).padStart(2, '0') + '-' + 
                 String(now.getDate()).padStart(2, '0');
    var timeStr = String(now.getHours()).padStart(2, '0') + ':' + 
                 String(now.getMinutes()).padStart(2, '0');
    
    var form = {
      target_date: dateStr,
      target_time: timeStr,
      target_type: 'clock_in'
    };
    
    var clockResult = postWorkRecord(form);
    
    if (clockResult === '登録しました') {
      return {
        success: true,
        message: '出勤打刻が完了しました'
      };
    } else {
      return {
        success: false,
        message: result || '出勤打刻に失敗しました'
      };
    }
  } catch (error) {
    console.error('clockIn: エラーが発生しました:', error);
    return {
      success: false,
      message: '出勤打刻中にエラーが発生しました'
    };
  }
}

function clockOut(employeeId) {
  try {
    
    var now = new Date();
    var dateStr = now.getFullYear() + '-' + 
                 String(now.getMonth() + 1).padStart(2, '0') + '-' + 
                 String(now.getDate()).padStart(2, '0');
    var timeStr = String(now.getHours()).padStart(2, '0') + ':' + 
                 String(now.getMinutes()).padStart(2, '0');
    
    var form = {
      target_date: dateStr,
      target_time: timeStr,
      target_type: 'clock_out'
    };
    
    var clockResult = postWorkRecord(form);
    
    if (clockResult === '登録しました') {
      return {
        success: true,
        message: '退勤打刻が完了しました'
      };
    } else {
      return {
        success: false,
        message: result || '退勤打刻に失敗しました'
      };
    }
  } catch (error) {
    console.error('clockOut: エラーが発生しました:', error);
    return {
      success: false,
      message: '退勤打刻中にエラーが発生しました'
    };
  }
}

function getClockStatus(employeeId) {
  try {
    
    var today = new Date();
    var timeClocks = getTimeClocksFor(employeeId, today);
    
    var hasClockIn = false;
    var hasClockOut = false;
    
    for (var i = 0; i < timeClocks.length; i++) {
      var record = timeClocks[i];
      if (record.type === 'clock_in') {
        hasClockIn = true;
      } else if (record.type === 'clock_out') {
        hasClockOut = true;
      }
    }
    
    var canClockIn = !hasClockIn;
    var canClockOut = hasClockIn && !hasClockOut;
    
    var message = '';
    if (canClockIn) {
      message = '出勤打刻が可能です';
    } else if (canClockOut) {
      message = '退勤打刻が可能です';
    } else if (hasClockIn && hasClockOut) {
      message = '本日の打刻は完了しています';
    } else {
      message = '打刻状態を確認中です';
    }
    
    return {
      canClockIn: canClockIn,
      canClockOut: canClockOut,
      message: message
    };
  } catch (error) {
    console.error('getClockStatus: エラーが発生しました:', error);
    return {
      canClockIn: false,
      canClockOut: false,
      message: 'エラーが発生しました'
    };
  }
}


