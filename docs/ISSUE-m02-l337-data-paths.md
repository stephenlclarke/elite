# M02: application-data defaults still use the previous product name

The reviewed L337 product still defaults to .xyzzy/elite for the commander file and both external mission libraries. Root explicitly activated this deferred naming slice: use .xyzzy/l337 for these three defaults only. Save backward compatibility is not required; no migration or legacy-path search is part of the fix.

Own only the path literals in CommanderSaveSession's defaultURL, MissionPackLibrary.userDirectory and ScriptPackLibrary.userDirectory. Preserve file formats, state, actor ownership, explicit user-selected paths, installer/content validation, bundle-resource names and M01 defaultLibrary lifetime fixes. Current-development instructions should match; published 1.4.0 download/Homebrew paths remain truthful to that release.
