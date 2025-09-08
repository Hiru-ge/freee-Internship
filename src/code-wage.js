/**
 * 給与計算システム
 * 時間帯別時給計算、月間勤務時間計算、給与計算を担当
 */

var TIME_ZONE_WAGE_RATES = {
  normal: { start: 9, end: 18, rate: 1000, name: '通常時給' },
  evening: { start: 18, end: 22, rate: 1200, name: '夜間手当' },
  night: { start: 22, end: 9, rate: 1500, name: '深夜手当' }
};


function getTimeZone(hour) {
  if (hour >= 9 && hour < 18) {
    return 'normal';
  } else if (hour >= 18 && hour < 22) {
    return 'evening';
  } else {
    return 'night';
  }
}

function calculateWorkHoursByTimeZone(shiftTime) {
  var parsedShift = parseShiftTime(shiftTime);
  if (!parsedShift) {
    return { normal: 0, evening: 0, night: 0 };
  }

  var startHour = parsedShift.startHour;
  var endHour = parsedShift.endHour;
  var timeZoneHours = { normal: 0, evening: 0, night: 0 };

  for (var hour = startHour; hour < endHour; hour++) {
    var timeZone = getTimeZone(hour);
    timeZoneHours[timeZone]++;
  }

  return timeZoneHours;
}

function calculateMonthlyWorkHours(employeeId, month, year) {
  var allShiftsJson = getShifts();
  if (!allShiftsJson) {
    return { normal: 0, evening: 0, night: 0 };
  }

  var allShifts = JSON.parse(allShiftsJson);
  var employeeShifts = allShifts.shifts[employeeId];
  
  if (!employeeShifts || !employeeShifts.shifts) {
    return { normal: 0, evening: 0, night: 0 };
  }

  var monthlyHours = { normal: 0, evening: 0, night: 0 };

  for (var day in employeeShifts.shifts) {
    var shiftTime = employeeShifts.shifts[day];
    if (shiftTime) {
      var dayHours = calculateWorkHoursByTimeZone(shiftTime);
      monthlyHours.normal += dayHours.normal;
      monthlyHours.evening += dayHours.evening;
      monthlyHours.night += dayHours.night;
    }
  }

  return monthlyHours;
}

function calculateMonthlyWage(employeeId, month, year) {
  try {
    var baseHourlyWage = getHourlyWage(employeeId);
    var timeZoneRates = TIME_ZONE_WAGE_RATES;
    var monthlyWorkHours = calculateMonthlyWorkHours(employeeId, month, year);

    var breakdown = {};
    var total = 0;

    for (var timeZone in monthlyWorkHours) {
      var hours = monthlyWorkHours[timeZone];
      var rate = timeZoneRates[timeZone].rate;
      var wage = hours * rate;
      
      breakdown[timeZone] = {
        hours: hours,
        rate: rate,
        wage: wage,
        name: timeZoneRates[timeZone].name
      };
      
      total += wage;
    }

    var wageCalculation = {
      total: total,
      breakdown: breakdown,
      workHours: monthlyWorkHours
    };
    
    return wageCalculation;
    
  } catch (error) {
    return {
      total: 0,
      breakdown: {},
      workHours: { normal: 0, evening: 0, night: 0 }
    };
  }
}

function getAllEmployeesWages(month, year) {
  var employees = getEmployees();
  if (!employees) {
    return JSON.stringify([]);
  }

  var allWages = [];
  
  employees.forEach(function(employee) {
    var wageInfo = calculateMonthlyWage(employee.id, month, year);
    
    allWages.push({
      employeeId: employee.id,
      employeeName: employee.display_name,
      wage: wageInfo.total,
      breakdown: wageInfo.breakdown,
      workHours: wageInfo.workHours,
      target: MONTHLY_WAGE_TARGET,
      percentage: (wageInfo.total / MONTHLY_WAGE_TARGET) * 100
    });
  });

  return JSON.stringify(allWages);
}

function getEmployeeWageInfo(employeeId, month, year) {
  try {
    var employees = getEmployees();
    if (!employees || employees.length === 0) {
      return JSON.stringify({
        error: '従業員情報が取得できません',
        employeeId: employeeId
      });
    }
    
    var employee = findEmployeeById(employeeId, employees);
    if (!employee) {
      return JSON.stringify({
        error: '指定された従業員IDが見つかりません',
        employeeId: employeeId
      });
    }
    
    var wageInfo = calculateMonthlyWage(employeeId, month, year);
    
    var employeeWageData = {
      employeeId: employeeId,
      employeeName: employee.display_name,
      wage: wageInfo.total,
      breakdown: wageInfo.breakdown,
      workHours: wageInfo.workHours,
      target: MONTHLY_WAGE_TARGET,
      percentage: (wageInfo.total / MONTHLY_WAGE_TARGET) * 100,
      isOverLimit: wageInfo.total >= MONTHLY_WAGE_TARGET,
      remaining: Math.max(0, MONTHLY_WAGE_TARGET - wageInfo.total)
    };
    
    return JSON.stringify(employeeWageData);
    
  } catch (error) {
    return JSON.stringify({
      error: '給与計算中にエラーが発生しました: ' + error.message,
      employeeId: employeeId
      });
  }
}

function getWageInfo(employeeId) {
  try {
    var now = new Date();
    var currentMonth = now.getMonth() + 1;
    var currentYear = now.getFullYear();
    
    
    var wageDataJson = getEmployeeWageInfo(employeeId, currentMonth, currentYear);
    var wageData = JSON.parse(wageDataJson);
    
    if (wageData.error) {
      return {wage: 0, target: MONTHLY_WAGE_TARGET, percentage: 0};
    }
    
    return {
      wage: wageData.wage,
      target: wageData.target,
      percentage: wageData.percentage
    };
  } catch (error) {
    return {wage: 0, target: MONTHLY_WAGE_TARGET, percentage: 0};
  }
}
