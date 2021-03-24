# PFRPG Malady Tracker
This extension handles automatic rolling of saving throws against poisons, diseases, and other types of maladies.

# Compatibility and Instructions
This extension has been tested with [FantasyGrounds Unity](https://www.fantasygrounds.com/home/FantasyGroundsUnity.php) 4.0.10 (2021-02-04).

For automatic saving throws, you must be using the [ClockAdjuster extension](https://www.fantasygrounds.com/forums/showthread.php?57561-Utility-Clock-Adjuster).

A potential issue to be aware of is the transition between micro and macro timekeeping (in/out of combat, basically).
Because the round counter can exceed 10, it progresses time as used for malady tracking (but doesn't advance the actual clock). The saving throw code should be 'smart' enough to handle this without rolling incorrect numbers of saves, but it will mean that when you reset the initiative counter the 'disease clock' go back a number of minutes (# of rounds previously in the combat tracker * 0.1)

# Features
* Tracks diseases or poisons that are incurred.
* If poison, show buttons to increaes DC or duration (for subsequent doses/exposure)
* Manual button to roll against listed save DC and announce success/failure
* Automated rolling of saving throws based on elapased time. There is a per-character on/off toggle on the character's disease list for those who want to roll their own. When turned off, it will prompt for the roll in chat.
* Automatic counting of rolled saves (automatic or manual), taking into account consecutive/nonconsecutive requirements.
* Automatic rolling of variable onset, duration, and frequency when the malady is added to the character.
* Notification message in the chat when a poison or disease that has multiple possible DCs is used (to remind the GM to set the DC).

# Video Demonstration (click for video)
[<img src="https://i.ytimg.com/vi_webp/VkTjPjuczYo/hqdefault.webp">](https://www.youtube.com/watch?v=VkTjPjuczYo)
