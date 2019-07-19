# vis-editorconfig

A [vis][vis] plugin for [editorconfig][ec].

[vis]: https://github.com/martanne/vis
[ec]: http://editorconfig.org/

## Installation

You'll need the Lua wrapper for editorconfig-core installed. This can be done through luarocks: `luarocks install editorconfig-core`

```shell
git clone https://github.com/vktec/vis-editorconfig "$HOME/.config/vis/editorconfig"
```

Then add `require "editorconfig/editorconfig"` to your `visrc.lua`.
