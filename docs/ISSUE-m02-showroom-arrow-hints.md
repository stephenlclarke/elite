# M02.P01: showroom arrow help conflicts with the active pane

The showroom help always says Up/Down selects a ship and also advertises arrows scrolling specifications. The actual showroomKey dispatch selects a ship in Browse/Search and scrolls in Specs. The specifications window can also fit all rows, leaving no additional row for an arrow to reveal. The unconditional hints therefore conflict with active input and can advertise an unavailable action.

Use the existing pane/search state and actual Display.showroomWindow overflow for the first contextual arrow hint. Retain browsing/search selection, Tab and Return navigation, profile-count hints, all six shared flight bindings and compact pagination. No key mapping, selection, renderer, quote, transaction, model or simulation change is required.
