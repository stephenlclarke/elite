# Restore README media and ark export recipe ownership

PR25 producer source0c80386d inserted the new `induction-ark-model` target between the existing README renderer and its icon conversion commands. Make therefore attached the icon commands to the exporter, causing an unnecessary iconset dependency and leaving README media without its final ICNS conversion. MBA reported [issue37](https://github.com/stephenlclarke/elite/issues/37).
