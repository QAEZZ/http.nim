import yaml
import streams
import os
import strformat
import tables

type Config = object
  port : int
  wwwroot_path : string
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

proc main(config: Config) : void =
  echo "\nVerifying integrity of mappings..."

  var
    pointless_mappings: seq[array[2, string]]
    routes: seq[string]

  for mapping in config.mappings:
    if not fileExists(fmt"{config.wwwroot_path}/{mapping[1]}"): pointless_mappings.add(mapping)
    
  if pointless_mappings.len > 0:
    echo "\n\e[0;31mWarn:\e[033;0m Found pointless mapping(s): "
    for mapping in pointless_mappings: echo " - ", mapping
    echo fmt"These mappings exist in the config, but the files don't exist in {config.wwwroot_path}."
  
  for mapping in config.mappings: routes.add(mapping[0])

  var duplicate_routes: seq[string] = findDuplicates(routes)

  if duplicate_routes.len > 0:
    echo "\n\e[0;31mWarn:\e[033;0m Found duplicate route(s): "
    for route in duplicate_routes: echo " - ", route
  

  echo "\nStarting webserver..." 



proc getConfig(): Config = 
  echo "Getting config..."

  var config: Config

  if not fileExists("./config.yaml"):
    echo "Config file not found.\nCreating one..."

    config.port = 80
    config.wwwroot_path = "./wwwroot"
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
  echo " - wwwroot: ", config.wwwroot_path
  echo " - mappings: "
  for mapping in config.mappings: echo "    * ", mapping
  echo " - disallow: "
  for disallow in config.disallow: echo "    * ", disallow

  if not dirExists(config.wwwroot_path):

    const html_boilerplate: string = """<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="ie=edge">
    <title>Webserver written in Nim!</title>
    <link rel="stylesheet" href="css/index.css">
  </head>
  <body>
	<script src="js/index.js"></script>
  </body>
</html>"""

    const css_boilerplate: string = "* {\nmargin: 0;\npadding: 0;\nbox-sizing: border-box;\noverflow-x: hidden;\n}"

    echo "\n\e[0;31mWarn:\e[033;0m Couldn't find '", config.wwwroot_path, "'; making one instead."

    createDir(config.wwwroot_path)
    createDir(fmt"{config.wwwroot_path}/css")
    createDir(fmt"{config.wwwroot_path}/js")
    createDir(fmt"{config.wwwroot_path}/assets")
    writeFile(fmt"{config.wwwroot_path}/robots.txt", "User-agent: *\nDisallow: /")
    writeFile(fmt"{config.wwwroot_path}/index.html", html_boilerplate)
    writeFile(fmt"{config.wwwroot_path}/css/index.css", css_boilerplate)
    writeFile(fmt"{config.wwwroot_path}/js/index.js", "console.log('Hello, World!');")

  main(config)
