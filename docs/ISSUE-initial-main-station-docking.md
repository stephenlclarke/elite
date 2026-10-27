# Initial SH025 main-station docking at native frame steps

Five retained MBA03 native mission tests stop at initial ordinary docking before contract acceptance, exhausting the existing 3000 advances of 0.1 seconds. The retained record does not expose their terminal controller phase, so this change does not claim to identify every cause of that historical failure.

Source analysis proves a sufficient entry blocker. The calibrated SH025 has radius 72.5470172564567 and maximum local Y 24.998768230193143; the unchanged main aperture ends at Y 32. The current conservative whole-step margin adds the ship and station absolute angular rates even at perfectly matched roll. With station radius 155.88457268119896, roll -0.3 and spin +0.3 over 0.1 seconds, that margin is 13.70589539625934, exceeding the actual 7.001231769806857 upper headroom. The aligned hull therefore fails the coarse aperture proof. Existing 0.02-second coverage receives a smaller 2.741179079251868 margin.

Preserve geometry, physics, controls, step budgets, clocks and genuine docking evidence. Refine a failed conservative proof over the same known attained native motion; do not fabricate a dock or relax a safety bound. Hostile docking and downstream mission qualification remain separate open work.
