import yaml
import streams
import os
import strformat
import tables
import std/net
import strutils
import selectors

type Config = object
  port : int
  wwwRootPath : string
  mappings : seq[array[2, string]]
  disallow : seq[string]

proc findDuplicates(seq: seq[string]): seq[string] =
  var seen: Table[string, int]
  var duplicates: seq[string]

  for element in seq:
    if element in seen:
      duplicates.add(element)
    else:
      seen[element] = 1

  duplicates

proc handleClient(client: Socket, config: Config) : void = 
  # TODO: actually look at config.mappings and see the routes/file paths.
  #       also return their respective MIME types.
  var dataBuffer = r""
  let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html" & "\r\n\r\n" & readFile(fmt"{config.wwwRootPath}/index.html")
  client.readLine(dataBuffer, timeout = -1, flags = {SafeDisconn})
  echo "Request: ", dataBuffer
  client.send(response)
  client.close()

proc main(config: Config) : void =
  echo "\nVerifying integrity of mappings..."

  var
    pointless_mappings: seq[array[2, string]]
    routes: seq[string]

  for mapping in config.mappings:
    if not fileExists(fmt"{config.wwwRootPath}/{mapping[1]}"): pointless_mappings.add(mapping)
    
  if pointless_mappings.len > 0:
    echo "\n\e[0;31mWarn:\e[033;0m Found pointless mapping(s): "
    for mapping in pointless_mappings: echo " - ", mapping
    echo fmt"These mappings exist in the config, but the files don't exist in {config.wwwRootPath}."
  
  for mapping in config.mappings: routes.add(mapping[0])

  var duplicate_routes: seq[string] = findDuplicates(routes)

  if duplicate_routes.len > 0:
    echo "\n\e[0;31mWarn:\e[033;0m Found duplicate route(s): "
    for route in duplicate_routes: echo " - ", route
  

  echo "\nStarting webserver..."

  let s = newSocket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
  s.bindAddr(Port(config.port))
  s.listen()

  while true:
    var client: Socket = Socket()
    accept(s, client)
    handleClient(client, config)

  # var client: Socket
  # var address = ""
  # while true:
  #   s.acceptAddr(client, address)
  #   echo "Client connection.\nAddress: ", address
  #   client.recv(s, 1024, timeout = -1, flags = {SafeDisconn})




proc getConfig(): Config = 
  echo "Getting config..."

  var config: Config

  if not fileExists("./config.yaml"):
    echo "Config file not found.\nCreating one..."

    config.port = 80
    config.wwwRootPath = "./wwwroot"
    config.mappings = @[["/", "index.html"], ["/index", "index.html"], ["/home", "index.html"]]
    config.disallow = @["not_allowed_to_view.txt", "test.txt", "secrets.txt"]

    var s = newFileStream("./config.yaml", fmWrite)
    Dumper().dump(config, s)
    s.close()

  var s = newFileStream("./config.yaml")
  load(s, config)
  s.close()
  
  return config


when isMainModule:
  let config: Config = getConfig()

  echo "Using config settings:"
  echo " - port: ", config.port
  echo " - wwwroot: ", config.wwwRootPath
  echo " - mappings: "
  for mapping in config.mappings: echo "    * ", mapping
  echo " - disallow: "
  for disallow in config.disallow: echo "    * ", disallow

  if not dirExists(config.wwwRootPath):

    const htmlBoilerplate: string = """<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="ie=edge">
    <title>Webserver written in Nim!</title>
    <link rel="stylesheet" href="css/index.css">
  </head>
  <body>
  <h1 style="position:absolute;left:50%;top:50%;transform:translate(-50%, -50%);">Hello, from Nim!</h1>
	<script src="js/index.js"></script>
  </body>
</html>"""

    const cssBoilerplate: string = "* {\nmargin: 0;\npadding: 0;\nbox-sizing: border-box;\noverflow-x: hidden;\n}\nbody { background-color: #202020; color: white; }"

    echo "\n\e[0;31mWarn:\e[033;0m Couldn't find '", config.wwwRootPath, "'; making one instead."

    createDir(config.wwwRootPath)
    createDir(fmt"{config.wwwRootPath}/css")
    createDir(fmt"{config.wwwRootPath}/js")
    createDir(fmt"{config.wwwRootPath}/assets")
    writeFile(fmt"{config.wwwRootPath}/robots.txt", "User-agent: *\nDisallow: /")
    writeFile(fmt"{config.wwwRootPath}/index.html", html_boilerplate)
    writeFile(fmt"{config.wwwRootPath}/css/index.css", css_boilerplate)
    writeFile(fmt"{config.wwwRootPath}/js/index.js", "console.log('Hello, World!');")

  main(config)
