import yaml
import std/[net, strformat, tables, os, streams, strutils, sequtils]

type Config = object
  port : int
  wwwRootPath : string
  mappings : seq[array[2, string]]
  disallow : seq[string]
  disallowReturn404 : bool

proc findDuplicates(seq: seq[string]): seq[string] =
  var seen: Table[string, int]
  var duplicates: seq[string]

  for element in seq:
    if element in seen:
      duplicates.add(element)
    else:
      seen[element] = 1

  duplicates

proc getMimeType(extension: string) : string =
  case extension:
  of "html","htm":
    return "text/html"
  of "json", "jsonc":
    return "application/json"
  of "wasm":
    return "application/wasm"
  of "pdf":
    return "application/pdf"
  of "wav":
    return "audio/s-wav"
  of "mp3":
    return "audio/mpeg"
  of "mp4":
    return "video/mp4"
  of "png":
    return "image/x-video"
  of "jpg","jpeg","jpe","jfif","pjpeg","pjp":
    return "image/jpeg"
  of "bmp":
    return "image/x-MS-bmp"
  of "gif":
    return "image/gif"
  of "tif","tiff":
    return "image/tiff"
  of "tar":
    return "x-tar"
  of "zip":
    return "x-zip-compressed"
  of "gz":
    return "x-gzip"
  of "exe":
    return "x-msdownload"
  of "js":
    return "text/javascript"
  of "css":
    return "text/css"
  else:
    return "text/plain"

proc handleClient(client: Socket, config: Config) : void = 
  var dataBuffer = r""
  client.readLine(dataBuffer, timeout = -1, flags = {SafeDisconn})
  let request = databuffer.split(" ")

  var 
    mimeType: string
    filePath: string = "MISSING"
    statusCode: string
    response: string
    isError: bool = false

  let requestedFile = request[1]

  for mapping in config.mappings:
    if mapping[0] == requestedFile:
      filePath = fmt"{config.wwwRootPath}/{mapping[1]}"
      statusCode = "200 OK"
      mimeType = getMimeType(mapping[1].split(".")[^1])
  
  for notAllowed in config.disallow:
    if notAllowed == requestedFile:
      statusCode = "403 Forbidden"
      if config.disallowReturn404:
        statusCode = "404 Not Found"
      mimeType = "text/plain"
      isError = true
      filePath = "NONE"
  
  if filePath == "MISSING":
    if fileExists(fmt"{config.wwwRootPath}{requestedFile}"):
      filePath = fmt"{config.wwwRootPath}{requestedFile}"
      statusCode = "200 OK"
      mimeType = getMimeType(requestedFile.split(".")[^1])
  
  if filePath == "MISSING":
    statusCode = "404 Not Found" 
    isError = true

  if isError:
    response = "HTTP/1.1 " & statusCode & "\r\nContent-Type: " & mimeType & "\r\n\r\n" & statusCode
  else:
    response = "HTTP/1.1 " & statusCode & "\r\nContent-Type: " & mimeType & "\r\n\r\n" & readFile(filePath)

  echo fmt"{request[0]} {request[1]}, {statusCode}"
  
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
  

  echo "\nStarting webserver...\n"

  let s = newSocket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
  s.bindAddr(Port(config.port))
  s.listen()

  while true:
    var client: Socket = Socket()
    accept(s, client)
    handleClient(client, config)


proc getConfig(): Config = 
  echo "Getting config..."

  var config: Config

  if not fileExists("./config.yaml"):
    echo "Config file not found.\nCreating one..."

    config.port = 80
    config.wwwRootPath = "./wwwroot"
    config.mappings = @[["/", "index.html"], ["/index", "index.html"], ["/home", "index.html"]]
    config.disallow = @["not_allowed_to_view.txt", "test.txt", "secrets.txt"]
    config.disallowReturn404 = false

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
