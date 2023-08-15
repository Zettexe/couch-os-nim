import os, npeg, strutils, sequtils, random, algorithm 

type
  DiceRoll = object
    value: int
    rerolled: bool

  Dice = object
    times: int
    value: int

  DiceOptions = object
    repeat: int
    explode: bool
    reroll: int
    rerollLow: int
    rerollHigh: int
    keep: int
    reverseKeep: bool

  Operator = object
    operator: char
    value: int
    realValue: int

  DiceList = object
    options: DiceOptions
    dice: seq[Dice]
    operators: seq[Operator]

  DiceResult = object
    diceTypes: seq[Dice]
    rolls: seq[seq[DiceRoll]]
    topRolls: seq[seq[DiceRoll]]
    total: int

  RollResult = object
    diceResults: seq[DiceResult]
    grandTotal: int 
    operatorTotal: Operator

const infinite = 1000000

let parser = peg("input", diceList: DiceList):
  Number <- {'1'..'9'} * *Digit

  repeat <- >?(Number * ' '):
    diceList.options.repeat = try: parseInt(($1).strip()) except ValueError: 1

  dice <- >?Number * 'd' * >+Number:
    diceList.dice.add(Dice(times: try: parseInt($1) except ValueError: 1, value: parseInt(capture[capture.len - 1].s)))

  operator <- *Space * >('+'|'-') * *Space * >Number:
    diceList.operators.add(Operator(operator: ($1)[0], value: parseInt($2), realValue: if $1 == "-": -parseInt($2) else: parseInt($2)))

  range <- >Number * ?((>(('<'|'>') * ?'=') | '-' * >?Number))

  reroll <- >?(Number | '*') * >(('r'|"reroll") | ('e'|"explode")) * range:
    diceList.options.reroll = if ($1).len > 0: (if ($1)[0] == '*': infinite else: parseInt($1)) else: 1
    diceList.options.explode = ($2)[0] == 'e'
    let low = parseInt($3)

    if capture.len > 4:
      try:
        let high = parseInt($4)
        diceList.options.rerollHigh = max(low, high)
        diceList.options.rerollLow = min(low, high)
      except ValueError:
        let offset_low = low - int(ord(not ('=' in $4)))
        if '<' in $4:
          diceList.options.rerollLow = 1
          diceList.options.rerollHigh = offset_low
        else:
          diceList.options.rerollHigh = infinite
          diceList.options.rerollLow = offset_low
    else:
      diceList.options.rerollLow = low
      diceList.options.rerollHigh = low

    diceList.options.rerollLow = min(diceList.options.rerollLow, infinite)
    diceList.options.rerollHigh = min(diceList.options.rerollHigh, infinite)


  keep <- ('k'|"keep") * >?'-' * >Number:
    diceList.options.reverseKeep = ($1).len > 0
    diceList.options.keep = parseInt($2)

  modifiers <- >('a' * ?i"dv" | 'd' * ?i"is") | ((reroll * *Space * ?keep) | (keep * *Space * ?reroll)):
    if capture.len > 1:
      diceList.options.keep = 1
      diceList.options.reverseKeep = ($1)[0] == 'd'

  dice_operator <- *Space * '+' * *Space * dice

  main <- repeat * dice * *dice_operator * *operator * ?(+Space * modifiers)

  input <- (>i"stats" | main) * !1:
    if capture.len > 1:
      diceList.options.repeat = 6
      diceList.options.reroll = infinite
      diceList.options.rerollLow = 1
      diceList.options.rerollHigh = 1
      diceList.options.keep = 3
      diceList.dice.add(Dice(times: 4, value: 6))
    
    diceList.options.keep = min(diceList.dice[0].times, diceList.options.keep)
    if not bool(diceList.options.keep):
      diceList.options.keep = diceList.dice[0].times

proc rollDice(dice: Dice, options: DiceOptions): seq[DiceRoll] =
  result = newSeq[DiceRoll](dice.times)
  for i in 0..<dice.times:
    var roll = rand(dice.value - 1) + 1
    var rerolled = false
    for _ in 0..<options.reroll:
      if roll >= options.rerollLow and roll <= options.rerollHigh:
        if options.explode:
          roll += rand(dice.value - 1) + 1
        else:
          roll = rand(dice.value - 1) + 1
          rerolled = true
      else:
        break
    result[i] = DiceRoll(value: roll, rerolled: rerolled)

proc populateDiceList(diceList: var DiceList): RollResult =
  var diceResults: seq[DiceResult] = @[]
  var grandTotal: int = 0
  for i in 0..<diceList.options.repeat:
    var diceResult: DiceResult
    var total: int = 0
    for dice in diceList.dice:
      let rolls = rollDice(dice, diceList.options)
      var sortedRolls = rolls
      sortedRolls.sort(proc (a, b: DiceRoll): int = cmp(b.value, a.value))
      let topRolls: seq[DiceRoll] = if sortedRolls.len >= diceList.options.keep: (if diceList.options.reverseKeep: sortedRolls[^diceList.options.keep .. ^1] else: sortedRolls[0 ..< diceList.options.keep]) else: sortedRolls
      let diceTotal = topRolls.foldl(a + b.value, 0)
      diceResult.diceTypes.add(dice)
      diceResult.rolls.add(rolls)
      diceResult.topRolls.add(topRolls)
      total += diceTotal
    
    diceResult.total = total
    diceResults.add(diceResult)
    grandTotal += total

  var operatorTotal: int = 0
  for operator in diceList.operators:
    operatorTotal += operator.realValue

  return RollResult(diceResults: diceResults, grandTotal: grandTotal, operatorTotal: Operator(operator: if operatorTotal >= 0: '+' else: '-', value: abs(operatorTotal), realValue: operatorTotal))

proc formatWidth(s: string, width: int): string =
  result = s
  while len(result) < width:
    result = " " & result

proc numberToWords(num: int): string =
  const ones = @["", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"]
  const tens = @["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety"]

  if num < 20:
    return ones[num]
  elif num < 100:
    return tens[num div 10] & (if num mod 10 > 0: "-" & ones[num mod 10] else: "")
  elif num < 1000:
    return ones[num div 100] & " hundred" & (if num mod 100 > 0: " and " & numberToWords(num mod 100) else: "")
  elif num < infinite:
    return numberToWords(num div 1000) & " thousand" & (if num mod 1000 > 0: " " & numberToWords(num mod 1000) else: "")
  else:
    return "infinite"

proc formatResult(d: DiceList, r: RollResult): string =
  let maxTotalWidth = r.diceResults.map(proc(x: DiceResult): int = ($x.total).len).max

  var result = "" 

  if r.diceResults.len > 1:
    result.add("Grand Total: " & $r.grandTotal & "\n")
  
  var unkeptDice = false
  for diceResult in r.diceResults:
    if r.diceResults.len > 1:
      result.add("- ")
    result.add("Total: " & formatWidth($(diceResult.total + r.operatorTotal.realValue), maxTotalWidth))
    if r.operatorTotal.value > 0:
      result.add(" (" & formatWidth($diceResult.total, maxTotalWidth) & $r.operatorTotal.operator & $r.operatorTotal.value & ")")
    result.add(", ")
    for i in 0..<diceResult.diceTypes.len:
      var rollStrings = newSeq[string](diceResult.rolls[i].len)
      for j in 0..<diceResult.rolls[i].len:
        let rollValue = if diceResult.rolls[i][j].rerolled: "\u035F" & $(diceResult.rolls[i][j].value) else: $(diceResult.rolls[i][j].value)
        rollStrings[j] = rollValue
      if r.diceResults[0].diceTypes.len > 1:
        result.add($diceResult.diceTypes[i].times & "d" & $diceResult.diceTypes[i].value & " [" & join(rollStrings, ", ") & "]")
      else:
        result.add("[" & join(rollStrings, ", ") & "]")
      if len(diceResult.topRolls[i]) != diceResult.diceTypes[i].times:
        unkeptDice = true
        var keptStrings = newSeq[string](diceResult.topRolls[i].len)
        for k in 0..<diceResult.topRolls[i].len:
          keptStrings[k] = $(diceResult.topRolls[i][k].value)
        result.add(" (kept: [" & join(keptStrings, ", ") & "])")
      if i < diceResult.diceTypes.len - 1:
        result.add(", ")
    result.add("\n")

  result.add("Rolled ")
  if r.diceResults.len > 1:
    result.add($r.diceResults.len & " times ")
  result.add("(" & join(map(d.dice, proc(x: Dice): string = $x.times & "d" & $x.value), "+") & ")")

  if unkeptDice:
    result.add(" keep: " & $d.options.keep)

  if d.options.reroll != 0:
    let rerollLow = if d.options.rerollLow >= infinite: "*" else: $d.options.rerollLow
    let rerollHigh = if d.options.rerollHigh >= infinite: "*" else: $d.options.rerollHigh
    result.add(" reroll: " & rerollLow)
    if rerollHigh != rerollLow:
      result.add("-" & rerollHigh)
    result.add(" " & numberToWords(d.options.reroll) & " times")

  return result

# let params = commandLineParams()
#
# randomize()
#
# # echo params.join(" ").strip()
#
# var diceList: DiceList
# if parser.match(params.join(" ").strip(), diceList).ok:
#   # echo diceList
#   let diceResults = populateDiceList(diceList)
#   # echo diceResults
# 
#   let text = formatResult(diceList, diceResults)
#   echo text
# else:
#   echo "Invalid Dice String"
