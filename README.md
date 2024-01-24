# http.nim
I've decided to start learning Nim, here is an (extremely) basic HTTP webserver.

Config Example:
```yaml
port: 80
wwwRootPath: ./wwwroot
mappings:
  - [/, index.html]
  - [/index, index.html]
  - [/home, index.html]
disallow: [/not_allowed_to_view.txt, /test.txt, /secrets.txt]
disallowReturn404: false
```