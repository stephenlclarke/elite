-- DESIGN EXAMPLE ONLY: proposed host API, not implemented in the current game.
-- Other handlers prepare travel, the whole encounter, grid jobs and story pages.
-- Native objective facts preserve the actual eight-plus-one admitted hull ledger.
local M = {}

function M.on_event(ctx, event, state)
  local data = ctx:copy_data(state)
  local commands = {}

  if event.kind == "body.destroyed" then
    if not ctx:owned_body("battle", event.body_id) then
      return { data = data, commands = commands }
    end

    local transports_done = ctx:objective_complete("transports")
    local flagship_done = ctx:objective_complete("flagship")
    if transports_done then
      commands[#commands + 1] = {
        op = "milestone.ensure", id = "transports",
        requires_objective = "transports"
      }
    end
    if flagship_done then
      commands[#commands + 1] = {
        op = "milestone.ensure", id = "flagship",
        requires_objective = "flagship"
      }
    end
    if transports_done and flagship_done and not data.finalTimerRequested then
      data.finalTimerRequested = true
      commands[#commands + 1] = {
        op = "timer.ensure", id = "final-sequence"
      }
    end
  elseif event.kind == "timer.fired" and event.timer_id == "final-sequence" then
    -- This is an actual engine timer receipt, never an elapsed-time guess.
    data.phase = "report"
    commands[#commands + 1] = {
      op = "dialogue.offer", id = "report"
    }
  elseif event.kind == "dialogue.confirmed" and event.dialogue_id == "report" then
    -- The host rechecks this token, station, person, objectives and timer receipt.
    -- Report, child completion and the calendar anchor are one native transaction.
    commands[#commands + 1] = {
      op = "dialogue.commit", id = "report", token = event.token,
      outcome = "complete", calendar_anchor = "epilogue"
    }
    data.phase = "complete"
  end

  return { data = data, commands = commands }
end

return M
