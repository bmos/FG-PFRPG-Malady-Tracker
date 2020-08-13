# PFRPG Disease Tracker
Just like my [Sanity Tracker](https://github.com/bmos/FG-PFRPG-Sanity-Tracker) extension, there is a new window accessible from each character sheet. Each window contains a list of afflictions. Each affliction is linked to a statblock matching Paizo's typical disease or poison format.
When the statblock is locked, a button will be shown to roll a saving throw against the affliction. If [ClockAdjuster](https://www.fantasygrounds.com/forums/showthread.php?57561-Utility-Clock-Adjuster/) is enabled, saves with frequencies measured in minutes or longer will also be rolled automatically once the time is set with the 'refresh' button (no rounds support at this time).

# Compatibility and Instructions
This extension has been tested with [FantasyGrounds Classic](https://www.fantasygrounds.com/home/FantasyGroundsClassic.php) 3.3.11 and [FantasyGrounds Unity](https://www.fantasygrounds.com/home/FantasyGroundsUnity.php) 4.0.0 (2020-08-05). The [ClockAdjuster](https://www.fantasygrounds.com/forums/showthread.php?57561-Utility-Clock-Adjuster/) extension has a known issue with FantasyGrounds Classic, please be aware that timed events (such as automatic saves) will not occur precisely except in Unity. For example, a 1/day save seems to take 25-26hours to occur.

# Features
* Track diseases or poisons that are incurred
* If poison, show buttons to increaes DC or duration (for subsequent doses/exposure)
* Manual button to roll against listed save DC and announce success/failure
* Automated rolling of saving throws based on elapased time. This requires pr6i6e6st's [Clock Adjuster](https://www.fantasygrounds.com/forums/showthread.php?57561-Utility-Clock-Adjuster) extension.
* Automatic counting of rolled saves (automatic or manual), taking into account consecutive/nonconsecutive requirements.

# Video Demonstration (click for video)
[<img src="https://i.ytimg.com/vi_webp/gBv50oSphBM/hqdefault.webp">](https://www.youtube.com/watch?v=gBv50oSphBM)
