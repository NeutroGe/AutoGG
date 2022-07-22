# AutoGG
A tool for the game league of legends on Microsoft Windows that automatically refreshes and serves players data with op.gg website so you dont have to do it manually!

This greatly helps you to understand the win condition of a ranked game before it even starts, so it helps you win more!

You might ask: "but why? There are already other apps that do the same, like blitz.gg or op.gg browser plugin". The problem with the other existing solutions is that they do not refresh datas from players automatically, so you get old, incomplete, not accurate informations about your current game. I created this app to specifically solve this problem.

## How does it work?

It's very simple: the app connects to your league of legend client and wait for you to start a game. When it detects that you are at a champion selection screen, it automatically gather all the names of the players in your team, then open their op.gg page (in the background using hidden internet explorer windows), click on the "refresh" button, gather "recently played with" informations and opens the summary page of all players on op.gg website. The "recently played with" informations are directly displayed on the app window.

When the game starts, it does the same with the enemy team.

So basically it's just doing automatically what you can already do manually! That's why it's safe to use, you will never get banned for using it and also it has been reviewed by riot (app ID 414403 on riot dev website).

## How to use?

The easier to understand is to watch this short demo video on youtube here: (placeholder text, youtube video link will be added here soon)

Summary:

On the right of this page, click on "v1.0" under the "releases" section to download a zip file containing the app. Just extract the zip and launch autogg.exe 

Some (stupid) antiviruses might get you a false positive when you launch it, but i guarantee that autogg.exe is only the compiled code that you can find here. If you have any doubt you can compile the program yourself, i explain how to do it further below.

Once the program is launched, a yuumi icon will show in your windows taskbar near the time and date. If you right click on it, you can enable or disable auto-opening of the op.gg summary page on your web browser once it's ready (optionnal).

Start a summoner's rift ranked game and let the magic happen!

## Contact

For any help or feedback, you can contact me here: https://discord.gg/cjjcrA2Zgp

I've only tested the app on euw servers but it should work on all servers worldwide. Please report to me on discord if you play on another server and get problems using it.

## How to compile the app yourself

If you want to compile the app yourself, here is how:

1. download and install autoit on your computer (around 10MB) - link: https://www.autoitscript.com/site/autoit/downloads/
(optional) download and install "AutoIt Script Editor" (around 5MB) - https://www.autoitscript.com/site/autoit-script-editor/downloads/

2. download the file "autogg.au3" that you can find here and open it with the autoit editor (right click on sstats.au3 -> edit)

3. press ctrl+F7 on the autoit editor to open the compile window, eventually select the yuumi.ico file (available here as well) if you want a nice icon then click "compile" which will generate the exe file of the app.

Warning: do not ask about summoner's stats in the official autoIT forums as they do not allow discussions about anything related to games inside.
 
## Disclamer (riot asks every 3rd party app devs to display the text below for legal reasons, dont give it too much attention)

Autogg isn't endorsed by Riot Games and doesn't reflect the views or opinions of Riot Games or anyone officially involved in producing or managing League of Legends. League of Legends and Riot Games are trademarks or registered trademarks of Riot Games, Inc. League of Legends © Riot Games, Inc.
