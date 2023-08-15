import dimscord, dimscmd
import httpclient, asynchttpserver
import asyncdispatch
import strformat, strutils
import json, options
import os, osproc, locks
import db_sqlite
import times, random
import threadpool

include "roll.nim"

# Evil CouchOS (Dev Bot 1)
const applicationID = "965556376606748694"
let discord = newDiscordClient("OTY1NTU2Mzc2NjA2NzQ4Njk0.GmHB30.2Kvg3K0qc-bkDxsgu8j4XV-HHvNFoxx24-F30M")

# bott (Dev Bot 2)
# const applicationID = "273450045913956353"
# let discord = newDiscordClient("MjczNDUwMDQ1OTEzOTU2MzUz.Gwgfs1.8hSFkljuIZVVpkMyZzzlXnCzDA85x_BcQ7ushc")

var cmd = discord.newHandler()

when defined(debug):
  const defaultGuildID = "273450731544248320"
else:
  const defaultGuildID = ""

const dns = "http://localhost"
const port = 10000

# Handle event for on_ready.
proc onReady(s: Shard, r: Ready) {.event(discord).} =
  # echo "Overwriting Commands..."
  # discard await discord.api.bulkOverwriteApplicationCommands(s.user.id, @[])
 
  when not defined(debug):
    for g in r.guilds:
      let guild = await discord.api.getGuild(g.id)
      let owner = await discord.api.getUser(guild.owner_id)
      echo fmt"Registered on ({guild.id}) ""{guild.name}"" by {owner.username}"

      echo "Deleting Guild Commands..."
      discard await discord.api.bulkOverwriteApplicationCommands(s.user.id, @[], guild_id = defaultGuildID)

  echo "Registering commands..."
  await cmd.registerCommands()
  echo "Ready as " & $r.user

proc interactionCreate (s: Shard, i: Interaction) {.event(discord).} =
  discard await cmd.handleInteraction(s, i)

proc interactionMessage(id: string, token: string, content: string, flags: set[MessageFlags] = {}) {.async.} =
  await discord.api.interactionResponseMessage(id, token, kind = irtChannelMessageWithSource, response = InteractionCallbackDataMessage(flags: flags, content: content))

proc interactionEditMessage(token: string, content: Option[string]) {.async.} =
  discard await discord.api.editInteractionResponse(applicationID, token, "@original", content = content)

proc egg(): string =
  let client = newHttpClient()
  client.headers = newHttpHeaders({ "Content-Type": "application/json" })
  
  let response = client.get("https://pixabay.com/api/?key=38365058-bab1ed220bf8fe26d57bca77a&q=egg&image_type=photo&category=food")
  
  if response.status == $Http200:
    let responseBody = parseJson(response.body)
    let images = responseBody["hits"]
    let randomIndex = rand(images.len - 1)
    let randomEggImageUrl = images[randomIndex]["webformatURL"].getStr()  # Get the image URL
    
    return fmt"{randomEggImageUrl}"
  else:
    return fmt"Failed to fetch image: {response.status}"

proc messageCreate (s: Shard, msg: Message) {.event(discord).} =
  if msg.author.bot: return
  discard await cmd.handleMessage("", s, msg)
  if "egg" in msg.content.toLower():
    discard await discord.api.sendMessage(msg.channelID, egg(), message_reference = msg.message_reference)

cmd.addChat("ping") do ():
  ## Pingers Pongers
  discard await discord.api.sendMessage(msg.channelID, fmt"pong your guild id is {msg.guild_id.get}")

cmd.addSlash("ping", guildID = defaultGuildID) do ():
  ## Pingers Pongers
  await interactionMessage(i.id, i.token, fmt"pong your guild id is: {i.guild_id.get}")

cmd.addSlash("begone", guildID = defaultGuildID) do ():
  ## Thot
  await interactionMessage(i.id, i.token, "Thot")

cmd.addSlash("celebrate", guildID = defaultGuildID) do ():
  ## Party woo!
  await interactionMessage(i.id, i.token, "🎉🎉🎉🎉🎊🎊🎊🎊🎈🎈🎈🧁🧁🥂")

cmd.addSlash("hello", guildID = defaultGuildID) do ():
  ## Says "Hello!", shocking right?
  await interactionMessage(i.id, i.token, "Hello!")

cmd.addSlash("shalom", guildID = defaultGuildID) do ():
  ## Hello but in Jewish
  await interactionMessage(i.id, i.token, "Greetings and may peace be upon you!")

cmd.addSlash("start", guildID = defaultGuildID) do ():
  ## "Starts" CouchOS
  await interactionMessage(i.id, i.token, "Welcome to CouchOS, please imput command_")

cmd.addSlash("quote", guildID = defaultGuildID) do ():
  ## Only the thiccest of quotes
  let data = newHttpClient().getContent("https://zenquotes.io/api/random").parseJson()[0]
  var quote = data["q"].getStr().strip(chars = {'\"'})
  var author = data["a"].getStr().strip(chars = {'\"'})
  
  quote = fmt("*\"{quote}\"*")

  await interactionMessage(i.id, i.token, fmt("{quote}\n-{author}"))

cmd.addSlash("pasta", guildID = defaultGuildID) do ():
  ## Italians look away
  const recipe = some("""
Ingredients: 160g Barilla Pasta, 50g Red bell pepper, 50g Leek, 50g Zucchini, 50g Eggplant, 40g Capers, 2 Tablespoons extra virgin olive oil, and Fresh basil

Instructions:
1. Wash and cut the leek into strips. 
2. Cut the bell pepper, Zucchini, and eggplant into small cubes. 
3. Wash and chop the capers. 
4. Heat the olive oil in a pan and sauté the eggplants. Set aside. 
5. Add more olive oil in the same pan and add in the rest of the vegetables; leek, red peppers, and zucchini. Add the chopped capers. 
6. Boil the pasta in a large amount of slightly salted boiling water. 
7. Drain the pasta, toss and sauté with the veggies. 
8. Sprinkle the sautéed eggplants. 
9. Drizzle with a little bit of olive oil, sprinkle fresh basil for the final touch and serve! 

Enjoy! ^-^
""")
  let embed = Embed(
    title: some("Pasta Recipe"),
    author: some(EmbedAuthor(name: "Chef CouchOS", icon_url: some("https://www.dropbox.com/s/4g0om3fb3vmne69/chef-couch-os.jpg?dl=1"))),
    description: recipe
  )
  await discord.api.interactionResponseMessage(i.id, i.token, kind = irtChannelMessageWithSource,
    response = InteractionCallbackDataMessage(embeds: @[embed])
  )

cmd.addSlash("restart", guildID = defaultGuildID) do ():
  ## Restart, Reboot, Reload
  await interactionMessage(i.id, i.token, "Restarting") 
  var dots = ""
  for c in "... ":
    dots.add c
    waitFor sleepAsync(0.25)
    await interactionEditMessage(i.token, some(fmt"Restarting{dots}"))
  
  waitFor sleepAsync(0.5)
  await interactionEditMessage(i.token, some("Loading"))
  
  dots = ""
  for c in "... ":
    dots.add c
    await sleepAsync(0.25)
    await interactionEditMessage(i.token, some(fmt"Loading{dots}"))
  
  await sleepAsync(0.5)
  await interactionEditMessage(i.token, some("Welcome to CouchOS, please imput command_"))

cmd.addSlash("crusade", guildID = defaultGuildID) do ():
  ## Deus Vult
  randomize()
  const list = ["DEUS VULT", "DUES VULT", "DORIME", "HABEMUS GLADII DOU", "SI VIS PACHEM PARA BELLUM"]
  let index = rand(high(list))
  await interactionMessage(i.id, i.token, list[index])

cmd.addSlash("encourage", guildID = defaultGuildID) do ():
  ## Positive vibes all around
  randomize()
  const list = ["You can do it!", "You got this!", "I believe in you!"]
  let index = rand(high(list))
  await interactionMessage(i.id, i.token, list[index])

cmd.addSlash("fuck", guildID = defaultGuildID) do ():
  ## Brandon?
  randomize()
  const list = ["Me ;)", "You", "Off",  "That", "It", "Yes", "This", "The Man"]
  let index = rand(high(list))
  await interactionMessage(i.id, i.token, list[index])

cmd.addSlash("recycle", guildID = defaultGuildID) do ():
  ## Plastic recycling is a lie!
  randomize()
  const list = ["Recycling is a concept. ♻️", "Big oil wants your money for profit!", "Make used new again.\nReuse, renew, recycle.\nKeep Earth beautiful.\n-kathy555", "Plastic recycling is a lie!"]
  let index = rand(high(list))
  await interactionMessage(i.id, i.token, list[index])

cmd.addSlash("god tier quote", guildID = defaultGuildID) do ():
  ## Gouda Tier Quotes
  randomize()
  const list = [
    "I'm going to do the Mario in the toilet\n-Charles Planet",
    "Peeing with a boner gives you maximum airtime\n-Charles Planet",
    "Your genital privileges have been removed\n-Couch",
    "I have tasted time and it tastes like really bad old grapes\n-Couch",
    "Good men have a dick in their pants. Great men, have a dick in their ass.\n-Charles Planet",
    "Starcutter this is an indie sci fi game not a strip club\n-Couch",
    "Gogurt in any form is banned in East Jesus\n-Couch",
    "||https://rb.gy/v1qgpl||",
    "VIVA LA VIRGIN\n-Couch",
    "hell me, the yes yes\n-charlie plaent",
    "Stop licking frog titties!\n-Couch yelling at Cow",
    "Fries are just Potatoes that fulfilled their dream\n-Tech Mari",
    "Why spend years training to reach enlightenment when you can just sit on a Kmart Roomba?\n-Couch",
    "Eating ass is forbidden beyond this point\n-Couch",
    "Couch if I married OS you'd be like, my mother in law\n-Kira to Couch",
    "Behold! The man unpissed\n-Charles Planet",
    "Its all fun and games until you give the Amish Google docs, and an air fryer\n-Charles Planet",
    "Where am I? Oh it appears to be Hell, brilliant\n-Couch",
    "Ara ara, me backrooms ( ͡° ͜ʖ ͡°)\n-Erioto and Charles Planet",
    "Not everything is a cock ring Charles\n-Couch to Charles Planet",
    "WikiHow: How to make you own groundhog\n-Starcutter",
    "Remember the chances of being murdered by a butter knife are slim, but never zero!\n-Tech Mari",
    "I am Canonically Immune to bread type attacks\n-Couch",
    "I can't believe I have to say this, but no cumming at Mario's funeral!\n-Couch",
    "Hey guys do you like wanna perform some necromancy tommorow night?\n-Couch",
    "Quick question, how big are your skin pores?\n-Couch",
    "slaps thighs Time to become a thicc bitch\n-Couch",
    "You've heard of friends with benefits, get ready for Chum and Cum\n-Charles Planet",
    "Pov: you are a person who actually unfolds the paper napkin to use it\n-Tech Mari",
    "As yes, HTTPS, the forbidden snack\ncrunches in javascript\n-Couch",
    "Sure you may be strong, but my power level is equal to the combined might of 7 round frogs\n-Couch",
    "Why hath the the twerking not commenced?\n-Cow",
    "Normalize leaving after the first red flag. Im not gonna do it but every one else should.\n-Hiro",
    "I seem to have accidentally circumcised someone.\n-Couch",
    "I want to ride an Arthropleura but like as a skateboard.\n-Couch",
    "Remeber kids, underaged sex is pretty cringe\n-Couch",
    "Remember kids, underaged drinking is cringe\n-Couch",
    "I'd kill for an Advanced Auto Parts Cinematic Universe\n-Charles Planet",
    "Got bored, started twerking\n-Couch",
    "Hi, weve been trying to reach you about your cars extended warranty",
    "Why is the boob angry\n-Couch",
    "Beware: Wyoming's revenge arc\n-Couch",
    "I want to go back to a time when I wasn't thinking about cum guzzling bacteria\n-Beefy",
    "You stole my friendship potassium!\n-Omar",
    "Fuck changing my lifestyle, I'ma buy teeth\n-Timely",
    "We are all frogs, some find us cute, others find us ugly\n-Beefy",
    "This is the cutest robbery Ive ever seen\n-Beefy",
    "I may be a moth, but I'm a moth who's seen some shit\n-Beefy"
  ]
  let index = rand(high(list))
  await interactionMessage(i.id, i.token, list[index])


proc eightBall(question: string, rolled: bool = false): string =
  const eightBall = [
    "It is certain.",
    "It is decidedly so.",
    "Without a doubt.",
    "Yes - definitely.",
    "You may rely on it.",
    "As I see it, yes.",
    "Most likely.",
    "Outlook good.",
    "Yes.",
    "Signs point to yes.",
    "Reply hazy, try again.",
    "Ask again later.",
    "Better not tell you now.",
    "Cannot predict now.",
    "Concentrate and ask again.",
    "Don't count on it.",
    "My reply is no.",
    "My sources say no.",
    "Outlook not so good.",
    "Very doubtful."
  ]
  const eightBallRolled = [
    "Rolling towards a yes.",
    "The ball rolls uncertainly.",
    "Definitely rolling towards a no.",
    "The roll is unclear, try again.",
    "The ball is rolling in your favor.",
    "The roll suggests a positive outcome.",
    "The roll suggests a negative outcome.",
    "The ball has rolled out of sight, outcome unknown.",
    "The roll is too fast, unclear result.",
    "The roll is slow and steady, good things are coming.",
    "The ball has stopped, the answer is no.",
    "The ball keeps rolling, the future is uncertain.",
    "The roll is smooth, it's a yes.",
    "The roll is bumpy, it's a no.",
    "The ball has rolled back to you, it's a definite yes.",
    "The ball has rolled away, it's a definite no.",
    "The roll is unpredictable, try again.",
    "The ball has rolled into the shadows, the outcome is uncertain.",
    "The roll is steady, it's a likely yes.",
    "The roll is erratic, it's a likely no."
  ]
  randomize()
  let index = rand(high(eightBallRolled))
  let response = if rolled: eightBallRolled[index] else: eightBall[index]
  return fmt"""**Q**: {question}
**A**: {response}
  """

cmd.addSlash("8ball", guildID = defaultGuildID) do (question: string = ""):
  ## What answers await thee?
  var response = ""
  if question.len > 0: 
    response = eightBall(question)
  else: 
    const nonAnswer = [
      "I'm an 8ball, not a mind reader. Please ask a question.",
      "Error 404: Question not found. Please try again.",
      "The spirits are confused. They can't find your question.",
      "I'm getting a strong sense of...nothing. Did you ask something?"
    ]
    let index = rand(high(nonAnswer))
    response = nonAnswer[index]
  await interactionMessage(i.id, i.token, response)

proc roll(message: string, content: string): string =
  const rollHelpString = """
Special:
  help: Shows this message
  stats: Rolls for DnD stats (6 4d6 *r1k3)
  8ball: Rolls an 8ball (8ball Is Orange a good color?)
  backyard: Rolls The Backyard

Syntax: W XdY(+XdY)(+Z)
  W is the amount of times to roll the dice string
  X is the amount of the following dice to roll
  Y is the amount of sides of the dice to roll
  Z is a static modifier for adding or subtracting to the total
  
  Items in parentheses are optional

Modifiers: rX kY
  Advantage: adv | a | dis | d
    adv or a is shorthand for keep 1 (k1)
    dis or d is shorthand for keep 1, lowest first (k-1)

    If you use this shorthand you cannot use any other modifiers

  Modifiers are attached to the end of the previous string with a space to separate them
  
  Reroll: XrY(-Z)(>=)(<=)(>)(<) XrerollY(-Z)(>=)(<=)(>)(<)
    X is the amount of times to reroll, may be * to represent infinity
    Y is the specific dice value to reroll
    Z is an optional value for specifying a range with '-' (e.g., *r1-3 for rerolling 1s and 2s and 3s)
  
  Keep: k(-)X keep(-)X
    X is the number of dice to keep, starting with the highest result
    Add '-' before X to keep dice starting from the lowest result instead
"""
  
  if message == "egg":
    return egg()
  elif message == "help":
    return rollHelpString
  elif message == "8ball":
    var output = ""
    let splitInput = content.split(" ")
    if splitInput.len > 2:
      output = eightBall(splitInput[2..^1].join(" "), true)
    else:
      const nonAnswer = [
        "The ball rolled away from your non-question. Try asking something.",
        "The roll is unclear...probably because there was no question.",
        "The ball rolled into a void of silence. Did you forget to ask?",
        "The roll suggests...wait, there's no question. Try again.",
      ]
      randomize()
      let index = rand(high(nonAnswer))
      output = nonAnswer[index]
    
    return output
  elif message == "backyard":
    return "A discordant symphony of noises assaults your ears, ranging from offensive racial slurs to the mundane noms of chewing, punctuated by the clatter of numerous dice.\nPrepare yourself, it's time to roll for initiative."
  
  randomize()
  
  let input = content.split(" ")[1..^1].join(" ")

  var diceList: DiceList
  if parser.match(input, diceList).ok:
    let output = formatResult(diceList, populateDiceList(diceList))
    return output
  
  return "Invalid Dice String"

var server = newAsyncHttpServer()
var endpoints: seq[(string, Time, string)] = @[]

proc serveEndpoints(req: Request) {.async, gcsafe.} =
  {.gcsafe.}:
    endpoints = endpoints.filterIt(getTime() - it[1] < initDuration(hours = 24))

    for endpoint in endpoints:
      let (path, _, content) = endpoint
      if req.url.path == "/" & path:
        var headers = newHttpHeaders()
        headers.add("Content-Type", "text/html")
        await req.respond(Http200, content, headers)
        return
  
  await req.respond(Http404, "Nah dawg aint nothin here, this bitch empty")

asyncCheck server.serve(Port(port), serveEndpoints)

proc generateEndpoint(guildID: string, content: string): string =
  let htmlContent = fmt"""<!DOCTYPE html>
<html lang="en">
  <head>
    <title></title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link rel="stylesheet" href="//unpkg.com/@highlightjs/cdn-assets@11.7.0/styles/default.min.css">
    <script src="//unpkg.com/@highlightjs/cdn-assets@11.7.0/highlight.min.js"></script>
    <script>hljs.highlightAll();</script>
  </head>
  <body>
    <pre>
      <code class="language-ruby">
        {content}
      </code>
    </pre>
  </body>
</html>
  """
  randomize()
  let uniqueID = $rand(high(int32)) & $rand(high(int32))

  endpoints = endpoints.filterIt(getTime() - it[1] < initDuration(hours = 24))
  endpoints.add((fmt"{guildID}/{uniqueID}", getTime(), htmlContent))
  
  let fport = if port != 80: fmt":{port}" else: ""

  return fmt"{dns}{fport}/{guildID}/{uniqueID}"

cmd.addChat("roll") do (message: string):
  var output = roll(message.strip().toLower(), msg.content.strip())
  
  if message.strip().toLower() == "egg":
    return
  
  if output.len > 2000:
    let guild_id = if msg.guild_id.is_some: msg.guild_id.get else: "DM"
    output = "Output too long:\n" & generateEndpoint(guild_id, output) & "\n" & output.split("\n")[^1]
  else:
    output = "```rb\n" & output & "\n```"

  discard await discord.api.sendMessage(msg.channelID, output)

cmd.addSlash("roll", guildID = defaultGuildID) do (message: string):
  ## roll egg
  let input = message.strip().toLower()

  var output = roll(input.split(" ")[0], "roll " & input)

  if output.len > 2000:
    output = "Output too long, available at:\n" & generateEndpoint(i.guild_id.get, output) & "\n" & output.split("\n")[^1]
  else:
    output = "```rb\n" & output & "\n```"
  
  await interactionMessage(i.id, i.token, output)

proc voice(v: VoiceClient) {.async.} =
  try:
    await v.startSession()
  except:
    echo "Error starting session, trying again"
    echo getCurrentExceptionMsg()
    await voice(v)

var queue: Table[string, seq[string]] = initTable[string, seq[string]]()

proc voiceServerUpdate(s: Shard, g: Guild, token: string; endpoint: Option[string]; initial: bool) {.event(discord).} =
  let v = s.voiceConnections[g.id]
  
  # echo initial

  v.voice_events.on_ready = proc (vc: VoiceClient) {.async.} =
    echo "REDY"

  v.voice_events.on_speaking = proc (vc: VoiceClient, s: bool) {.async.} =
    if not vc.speaking:
      echo "SONG OVER MOTHERFUCKER"
      queue[g.id].delete(0)
      if queue[g.id].len > 0:
        asyncCheck vc.playFFMPEG(queue[g.id][0])
      else:
        echo "NO MORE SONGS IN THIS NEIGHBORHOOD"

  v.voice_events.on_disconnect = proc (vc: VoiceClient) {.async.} =
    queue[g.id] = @[]
    vc.stopPlaying()

  if initial: await voice(v)

proc join(s: Shard, i: Interaction, channel: Option[dimscord.GuildChannel]): Future[string] {.async.} =
  let guildID = i.guild_id.get
  let userID = i.member.get.user.id

  let guild = s.cache.guilds[guildID]
  
  var channelID = guild.voicestates[userID].channelId.get
  if channel.isSome:
    channelID = channel.get.id

  if not channel.isSome and not guild.voice_states.hasKey(userID):
    return "You're not connected to a voice channel"
    
  if s.voiceConnections.hasKey(guildID) and s.voiceconnections[guildID].channelID == channelID:
    return "Already connected to the targeted voice channel"

  # echo channelID
  await s.voiceStateUpdate(guildID = i.guild_id.get, channelID = channelID.some, selfDeaf = true)
  return "Connected to voice channel"

cmd.addSlash("join", guildID = defaultGuildID) do (channel: Option[dimscord.Channel]):
  ## Join a voice channel, use the format @!channel_name
  if channel.isSome and channel.get.kind != ctGuildVoice:
    await interactionMessage(i.id, i.token, "Channel needs to be a voice channel", {mfEphemeral})
  
  await interactionMessage(i.id, i.token, await join(s, i, channel), {mfEphemeral})

cmd.addSlash("leave", guildID = defaultGuildID) do ():
  ## Leave the current voice channel
  if not (i.guildID.get in s.voiceconnections):
    await interactionMessage(i.id, i.token, "Not connected to a voice channel", {mfEphemeral})
    return
  
  await s.voiceStateUpdate(guildID = i.guild_id.get)
  await interactionMessage(i.id, i.token, "Disconnected from voice channel", {mfEphemeral})

type
  QueryInfo = object
    result: tuple[valid: bool, url: string]
    isDone: bool

proc isVideoValid(query: string, qi: ptr QueryInfo) {.thread.} =
  let output = execProcess("yt-dlp", args = ["--get-url", query], options = {poUsePath, poStdErrToStdOut})
  let first = output.split("\n")[0]
  var sec = output.split("\n")[1]

  if not sec.startsWith("http"): 
    if not first.startsWith("http"):
      qi.result = (false, output)
      qi.isDone = true
      return
    sec = first

  qi.result = (true, sec)
  qi.isDone = true

# Causes interruption since execProcess is not async
#
# proc isVideoValidAsync(query: string): Future[(bool, string)] {.async.} =
#   let output = execProcess("yt-dlp", args = ["--get-url", query], options = {poUsePath, poStdErrToStdOut})
#   let first = output.split("\n")[0]
#   let sec = output.split("\n")[1]
# 
#   if not first.startsWith("http") and not sec.startsWith("http"):
#     return (false, output)
#   
#   if not sec.startsWith("http"):
#     return (true, first)
#   
#   return (true, sec)

cmd.addSlash("play", guildID = defaultGuildID) do (query: string, channel: Option[dimscord.Channel]):
  ## Play some sounds
  if channel.isSome and channel.get.kind != ctGuildVoice:
    await interactionMessage(i.id, i.token, "Channel needs to be a voice channel", {mfEphemeral})
  
  await discord.api.interactionResponseMessage(i.id, i.token, kind = irtDeferredChannelMessageWithSource, response = InteractionCallbackDataMessage(flags: {mfEphemeral}, content: ""))
  
  if not (i.guildID.get in s.voiceconnections) or channel.isSome:
    echo await join(s, i, channel)
 
  # async await threading magic
  var queryInfo: QueryInfo
  spawn isVideoValid(query, addr(queryInfo))
  while not queryInfo.isDone:
    await sleepAsync 10

  let (isValid, url) = queryInfo.result

  # let (isValid, url) = await isVideoValidAsync(query)

  if not isValid:
    await interactionEditMessage(i.token, some("Invalid URL"))
    return

  while not (i.guild_id.get in s.voiceconnections) or not s.voiceconnections[i.guild_id.get].ready: 
    await sleepAsync 10

  let vc = s.voiceConnections[i.guildID.get]

  if i.guild_id.get in queue:
    queue[i.guild_id.get].add(url)
  else:
    queue[i.guild_id.get] = @[url]

  if not vc.speaking and queue[i.guild_id.get].len == 1:
    asyncCheck vc.playFFMPEG(url)

  await interactionEditMessage(i.token, some("Added song to queue"))

cmd.addSlash("stop", guildID = defaultGuildID) do ():
  ## Stops the music and clears the queue
  while not (i.guild_id.get in s.voiceconnections) or not s.voiceconnections[i.guild_id.get].ready: 
    await sleepAsync 10

  let vc = s.voiceConnections[i.guildID.get]
  queue[i.guildID.get].setlen(1)
  vc.stopPlaying()
  await interactionMessage(i.id, i.token, "Stopped the music", {mfEphemeral})

cmd.addSlash("skip", guildID = defaultGuildID) do ():
  ## Skips to the next track in the queue
  while not (i.guild_id.get in s.voiceconnections) or not s.voiceconnections[i.guild_id.get].ready: 
    await sleepAsync 10

  let vc = s.voiceConnections[i.guildID.get]
  vc.stopPlaying()
  await interactionMessage(i.id, i.token, "Skipped song", {mfEphemeral})

cmd.addSlash("pause", guildID = defaultGuildID) do ():
  ## Toggles if the music is paused
  while not (i.guild_id.get in s.voiceconnections) or not s.voiceconnections[i.guild_id.get].ready: 
    await sleepAsync 10

  let vc = s.voiceConnections[i.guildID.get]
  if vc.paused:
    vc.resume()
    await interactionMessage(i.id, i.token, "Unpaused Music", {mfEphemeral})
    return

  await interactionMessage(i.id, i.token, "Paused Music", {mfEphemeral})
  vc.pause()

cmd.addSlash("unpause", guildID = defaultGuildID) do ():
  ## Unpauses the music
  while not (i.guild_id.get in s.voiceconnections) or not s.voiceconnections[i.guild_id.get].ready: 
    await sleepAsync 10

  let vc = s.voiceConnections[i.guildID.get]
  if not vc.paused:
    vc.resume()
    await interactionMessage(i.id, i.token, "Unpaused Music", {mfEphemeral})
    return

  await interactionMessage(i.id, i.token, "Music aint paused dawg what yo doin", {mfEphemeral})

let db = open("schedules.db", "", "", "")

db.exec(sql("""
  CREATE TABLE IF NOT EXISTS activities (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    scheduled_for INTEGER
  )
"""))

cmd.addSlash("schedule add", guildID = defaultGuildID) do (name: string, channel: Option[dimscord.Channel]):
  ## Adds an item that can be scheduled
  if channel.isSome and channel.get.kind != ctGuildVoice:
    await interactionMessage(i.id, i.token, "Channel needs to be a voice channel", {mfEphemeral})

  await interactionMessage(i.id, i.token, "Pee pee dont use this yet", {mfEphemeral})

cmd.addSlash("schedule remove", guildID = defaultGuildID) do ():
  ## Removes an item
  await interactionMessage(i.id, i.token, "Pee pee dont use this yet", {mfEphemeral})

waitFor discord.startSession()
