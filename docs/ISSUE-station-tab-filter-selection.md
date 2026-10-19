# Shared Tab helper hides the failed engagement stage

Qualification 687 at a3985f61086be35ae2ad2d3f7b4ea485aecd8a86 reports EquipmentGroupTests.swift:214, requiring main station zero and docking engagement. The same helper serves four different engagement stages. Neither the raw log nor event stream reports the call stage, selections, current screen, pause state or notification. The batch subsequently crashed in an unrelated NPC journey.

Source inspection confirms that the ships filter includes docking, the installed military core admits stations, and the controller cycles eligible candidates within the existing body-count bound. C has no flight docking action. A paused or non-flight state would prevent Tab acquisition, but the available evidence does not establish that cause. No production behavior correction is justified yet.
