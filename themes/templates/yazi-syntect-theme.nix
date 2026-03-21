{ lib, theme }:
''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>name</key>
        <string>${theme.familyTitle} ${theme.flavorTitle}</string>
        <key>settings</key>
        <array>
          <dict>
            <key>settings</key>
            <dict>
              <key>background</key>
              <string>${theme.hex "base"}</string>
              <key>foreground</key>
              <string>${theme.hex "text"}</string>
              <key>caret</key>
              <string>${theme.hex "rosewater"}</string>
              <key>selection</key>
              <string>${theme.hex "surface0"}</string>
              <key>invisibles</key>
              <string>${theme.hex "overlay0"}</string>
              <key>lineHighlight</key>
              <string>${theme.hex "mantle"}</string>
            </dict>
          </dict>
          <dict>
            <key>name</key>
            <string>Comment</string>
            <key>scope</key>
            <string>comment</string>
            <key>settings</key>
            <dict>
              <key>foreground</key>
              <string>${theme.hex "overlay1"}</string>
              <key>fontStyle</key>
              <string>italic</string>
            </dict>
          </dict>
          <dict>
            <key>name</key>
            <string>String</string>
            <key>scope</key>
            <string>string</string>
            <key>settings</key>
            <dict>
              <key>foreground</key>
              <string>${theme.hex "green"}</string>
            </dict>
          </dict>
          <dict>
            <key>name</key>
            <string>Keyword</string>
            <key>scope</key>
            <string>keyword, storage</string>
            <key>settings</key>
            <dict>
              <key>foreground</key>
              <string>${theme.hex "mauve"}</string>
            </dict>
          </dict>
          <dict>
            <key>name</key>
            <string>Function</string>
            <key>scope</key>
            <string>entity.name.function, support.function</string>
            <key>settings</key>
            <dict>
              <key>foreground</key>
              <string>${theme.hex "blue"}</string>
            </dict>
          </dict>
          <dict>
            <key>name</key>
            <string>Type</string>
            <key>scope</key>
            <string>entity.name.type, support.type, support.class</string>
            <key>settings</key>
            <dict>
              <key>foreground</key>
              <string>${theme.hex "yellow"}</string>
            </dict>
          </dict>
          <dict>
            <key>name</key>
            <string>Constant</string>
            <key>scope</key>
            <string>constant, constant.numeric</string>
            <key>settings</key>
            <dict>
              <key>foreground</key>
              <string>${theme.hex "peach"}</string>
            </dict>
          </dict>
          <dict>
            <key>name</key>
            <string>Variable</string>
            <key>scope</key>
            <string>variable, variable.parameter</string>
            <key>settings</key>
            <dict>
              <key>foreground</key>
              <string>${theme.hex "text"}</string>
            </dict>
          </dict>
          <dict>
            <key>name</key>
            <string>Punctuation</string>
            <key>scope</key>
            <string>punctuation</string>
            <key>settings</key>
            <dict>
              <key>foreground</key>
              <string>${theme.hex "overlay2"}</string>
            </dict>
          </dict>
          <dict>
            <key>name</key>
            <string>Invalid</string>
            <key>scope</key>
            <string>invalid</string>
            <key>settings</key>
            <dict>
              <key>foreground</key>
              <string>${theme.hex "red"}</string>
            </dict>
          </dict>
        </array>
      </dict>
    </plist>
  ''
