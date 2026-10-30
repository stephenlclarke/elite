Commies for Giles William's Oolite

by Dr. Nil

2.20 Feb 2026
Updated some PNG files to remove invalid colour profile.

2.19 August 2023
Cleaned up shipdata.plist. Added a new texture + normal map for the Astromine Penal Colony while we await GearsNSuch's updated model and textures. Added normal map to the Manta Ray carrier. Added extra shipyard.plist entry for player version of the Military Stingray. 

2.18 August 2019
Added improved graphics and updated shipdata.plist and shiplibrary.plist. Also removed some deprecated files from the Config folder. The models and textures for the Astromine Convict Pod, the Workers' Commuter, The Commissar Limousine, and the Ray (and derivatives) have been replaced with new, from-scratch graphics created by GearsNSuch with Blender (blender.org) and GIMP (gimp.org). Shipdata.plist has been updated and cleaned up to incorporate these graphical changes and add names to the different models of spacecraft. A shiplibrary.plist file has been added as well, with descriptions drawn from original material and the Oolite Wiki (wiki.alioth.net). All models and textures are licensed under the CC BY-NC-SA 3 license.

2.17
Fixed populator issues that were (a) preventing Commissar Limousines from being spawned, and (b) preventing Giant Ray's from being spawned in Intergalactic space. Also made it possible to save the game at Astro Factories and Collective SLAPU stations.

2.16 March 2017
Fixed semicolon problems in Mac, thanks to hoqllnq.

2.15 January 2017
Added code to utilize Station Validator, if installed.
Added improved texture files, courtesy of Keeper.

2.14 November 2016
Updated scripts and config for current version of Oolite (1.82 and onwards)

2.13 April 2016
Edited the quotes out of the name of Sun Ray to avoid the computer pronouncing them audibly when it's passing on the radio chatter.

2.12 April 2012
This amended readme refers to Amaranth's additional textures for Commies OXP. I have not modified the models and scripting in any way and this remains the work of Dr Nil.

I have created the textures from a number of sources

Initial texture design and ideas are based on Dr Nil's original, combined with textures found via a google image search.

The exceptions to this are the escape pod (incorporating photos I took of the Soyuz capsule in the Polish Military Museum, Warsaw) and parts of the docking bay, based on photos of mine of derelict buildings.
_____

This work is licensed under the Creative Commons Attribution-Noncommercial-Share Alike 3.0 Unported License. To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 171 Second Street, Suite 300, San Francisco, California, 94105, USA.
_____

Read Captain Hesperus' descriptions of commie systems and ships here: http://wiki.alioth.net/index.php/Powers_and_Organisations#Communist_States


* * * * *

2.11 mei 2010

Added reflection and illumination maps for some of the stations.

2.10 April 2010

Corrected the role for the ecm-proof-missiles. Has always been wrong resulting in launching plain missiles for some of the ships.

2.09 October 2009

Centered the stations so the are now centered in the players target-reticule.
Changed the addition distance for solar stations from a general distance into a value relative to the sun radius. Stations no longer explode because of being added to close near big suns. With smaller suns the distance is even closer to the sun now.

2.08 September 2009

Translated the main script into Java Script. (When used with Oolite 1.65 it will fall back on the old script)
Corrected an very old type flasher definition. (Still worked before but would be skipped with Oolite 1.73)
Launching workcoms now head for a commies station instead of docking at the same station (Oolite 1.72-) or "wormholing" away (Oolite 1.73+)
Removed comguardAI: Was wrong and unused.
Updated some AI based on Oolite 1.55 trader AI to that of 1.65 trader AI (Better avoidance of obstacles)
Removed a bug were ships without fuel-scoop scanned for debris. Although the AI never intended to scoop them, scanForRandomLoot never finds anything when there are no scoops.
Fixed bug with fuel_injection of comlim (typo)

2.07 March 2008

Corrected a typo in an AI spotted by Ahruman


2.06 Jan 2008

A bug in the shipdata squashed by honorary commissar Kaks


2.05 November 2007

Some more propaganda posters.


2.04 April 2007

4 new propaganda posters.

2.03 April 2007

Fixed an issue with the units for Gold, Platinum and Gems at some of the stations.

2.0 February 2007

New model for the Astromines.
Fixed commodities for SLAP-Us, CZGFs and Astromines.
4 new propaganda posters.


1.85 Jan 2007

A new ship for the Commissar Limousine (Party Liner): The Sturgeon. The Comissar Limousines now use Military Rays for escorts.


1.8 Dec 2006

Added Neuropol Info Service (AD-X screens from YOUR_AD_HERE.oxp fitted with communist messages) as Navigational Buoy in Rich Industrial commie systems.

Credits:
Propaganda Poster 1: johnsmith
Propaganda Poster 2: HueijRevisited


1.7 Dec 2006

Made the script a lot more compact and did a minor change in shipdata.plist


1.6 Nov 2006

Updated model for the CZGF + a  little detail work on some other models and textures.


1.5 Nov 2006

Giant Ray gunships for communist military added. (Used ballturrets and some AI from Behemoth.oxp).
Stopped Factories from appearing in interplanetary space.


1.4 Nov 2006

Added Astromine Penal Colonies.


1.31 Nov 2006

Increased Energy Recharge Rate of factories by 50% and gave them shieldEnhancement to stop them from exploding too often in systems with large suns. Also the script now decides the appearance of Commissar Limousines and Worker's Commuters one by one instead of in pairs.


1.3 Nov 2006

An additional factory model: Solar Laboratory and Production Unit (SLAP-U) and textures for the Worker's Commuter in less worn states.


1.2 Nov 2006

Added the new Collective Zero G Factory which appears in communist systems with tech level 7 or above and sell tech 10 equipment at affordable prices - look for F on your advanced space compass to find it.

Updated the script and AI for the political police.


1.1 Nov 2006

If you already installed 1.0 delete the following folders before installing:
Commie_vipers.oxp
Political Police.oxp
Worker's Commuter.oxp
Commissar Limousine.oxp

The Commies now come in a single folder: Commies.oxp

This version gives local communist police the new tough Ray MK-I crafts with built in scoops and there's a new model for the Worker's Commuter.


1.0 Oct 2006

Some ships scripted to appear in communist systems:

People's Vipers - Communist system now require Gal-Cop to have a certain percentage of local police in their ranks, to limit outside interference.

Political Police - Don't know what to think? Well you better not. These guys will tell you what to think. Criminals whose escape pods get scooped by these guys can look forward to decades in the Astromines.

Commissar Limousine and escorts - The hard working nomenclature likes to travel in style with lots of comfort and protection.

Workers' Commuter - These systems are the working critter's paradises and the governments provide the worker's with public transportation (only slightly used).

Stuff used for these cut and paste plus a little scripting OXPs:

Oolite by Giles Willams - Vipers and Political Police
Executive Spaceways OXP by Ramirez - Commissar Limousine and escorts
mPak OXP by Murgh - Workers' Commuter


***** Known crashing problems ******

Some combination of graphics card drivers and ships are crashing Oolite in shader mode, even when no shaders are used at all. When having crashes in shader mode but no crashes when turned off, it is a good sign you should update your drivers. In commies it is the "Collective ZGF" station that can crash some systems. When in doubt if it might affect your computer you should launch Oolite, press "N" and wait for the Collective ZGF station appearing. When it shows up without crashing your system is okay.

A nVidia GeForce 7950GT 512Mb PCI-E graphics card, with the 64-bit drivers version 178.13 is known to crash with commies and other oxps while driver version 191.07 works okay. It seems that turning "Threading Optimisation" off will also help for computers with these cards.

Solution would be to remove this oxp but than you might get other oxp's containing problem objects. So better update your drivers or leave "Threading Optimisation" off for Oolite in combination with this old GPU.
