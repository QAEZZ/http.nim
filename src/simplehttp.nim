import yaml
import streams
import yaml/hints
import os

type Config = object
  port : int
  wwwroot_path : string
  mappings: seq[array[2, string]]
  disallow: seq[string]

proc getConfig(): void =  # TODO: return type Config
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
  defer: s.close()
  
  echo "Using config settings:"
  echo " - port: ", config.port
  echo " - wwwroot: ", config.wwwroot_path
  echo " - mappings: "
  for mapping in config.mappings: echo "    * ", mapping
  echo " - disallow: "
  for disallow in config.disallow: echo "    * ", disallow


when isMainModule:
  getConfig()
