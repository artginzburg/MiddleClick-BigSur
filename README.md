<a href="https://github.com/artginzburg/MiddleClick-Sonoma/releases">
  <img align="right" src="https://img.shields.io/github/downloads/artginzburg/middleclick-sonoma/total?color=teal" title="GitHub All Releases">
</a>

<div align="center">
  <h1>
    MiddleClick <img align="center" height="80" src="MiddleClick/Images.xcassets/AppIcon.appiconset/mouse128x128.png">
  </h1>
  <p>
    <b>Emulate a scroll wheel click with three finger Click or Tap on MacBook trackpad and Magic Mouse</b>
  </p>
  <p>
    with <b>macOS</b> Sonoma<a href="https://www.apple.com/macos/sonoma/"><sup>14</sup></a> support!
  </p>
  <br>
</div>

<img src="demo.png" width="55%">

<h2 align="right">:mag: Usage</h2>

<blockquote align="right">

It's more than just `⌘`+click

</blockquote>

<p align="right">

`System-wide` · close tabs by middleclicking on them

</p>

<p align="right">

`In Safari` · middleclicking on a link opens it in the background as a new tab

</p>

<p align="right">

`In Terminal` · paste selected text

</p>

<br>

## Install

### Via :beer: [Homebrew Cask](//brew.sh) (Recommended)

```ps1
brew install --cask --no-quarantine middleclick
```

> Check out [the cask](https://github.com/Homebrew/homebrew-cask/blob/master/Casks/m/middleclick.rb) if you're interested

### Direct Download

<details>
  <summary>
    <a href="https://github.com/artginzburg/MiddleClick-Sonoma/releases/latest/download/MiddleClick.zip">
      Latest Release
    </a>&nbsp·&nbsp
    <a href="https://github.com/artginzburg/MiddleClick-Sonoma/releases/latest">
      <img align="center" alt="GitHub release" src="https://img.shields.io/github/release/artginzburg/middleclick-Sonoma?label=%20&color=gray">
    </a>
  </summary>

> Additionally, you may also view <a href="https://github.com/artginzburg/MiddleClick-Sonoma/releases">Earlier Releases</a>

</details>

<br>

### Hide Status Bar Item

1. Holding `⌘`, drag it away from the status bar until you see a :heavy_multiplication_x: (cross icon)
2. Let it go

> To recover the item, just open MiddleClick when it's already running

### Add Login Item

> Make it open automatically when you log in

<details>

<summary>Just add MiddleClick to your "Login Items". <p align="right">(it's handy to be done using command line)</p></summary>

```ps1
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/MiddleClick.app", hidden:true}'
```

</details>

## Preferences

### Number of Fingers

- Want to use 4, 5 or 2 fingers for middleclicking? No trouble. Even 10 is possible.

```ps1
defaults write com.rouge41.middleClick fingers 4
```

> Default is 3

### Allow to click with more than the defined number of fingers.

- This is useful if your second hand accidentally touches the touchpad.
- Unfortunately, this does not serve as a palm rejection technique for huge touchpads.

```ps1
defaults write com.rouge41.middleClick allowMoreFingers true
```

> Default is false, so that the number of fingers is precise

### Tapping preferences

#### Max Distance Delta

- The maximum distance the cursor can travel between touch and release for a tap to be considered valid.
- The position is normalized and values go from 0 to 1.

```ps1
defaults write com.rouge41.middleClick maxDistanceDelta 0.03
```

> Default is 0.05

#### Max Time Delta

- The maximum interval in milliseconds between touch and release for a tap to be considered valid.

```ps1
defaults write com.rouge41.middleClick maxTimeDelta 150
```

> Default is 300

### Ignoring certain applications

- You can disable MiddleClick for certain app windows by providing a list of app bundles to ignore

```ps1
defaults write com.rouge41.middleClick ignoredAppBundles -array com.microsoft.rdc.macos com.apple.Terminal
```

---

<details>
  <summary>This fork differs from the <a href="//github.com/cl3m/MiddleClick">base fork</a> in some ways</summary>

- Configurations: Number of Fingers, Click or Tap
  - preferred setting is saved for every user
- Removed old 32-bit/PowerPc `relaunch` binary due to it's incompatibility with macOS 10.15 Catalina and greater. Replaced with inline restarting of the app
- The App will not only restart on waking the Mac, but when a new touch device is added (so it immediately gains middleclicking ability) and when a display is added/reconfigured (for proper click positioning)
</details>

#### Attention! Make sure to:

1. Quit an old version of MiddleClick
2. Remove it from the privacy settings
3. Enable the new version in privacy settings when prompted

> The app should be closed when you change the privacy settings, otherwise the Mouse may not be clickable and you may have to `killall MiddleClick` via terminal or even force restart the Mac.

<details>
  <summary><b>Credits</b></summary>
  <blockquote>
  <br>

This project was made by [Clément Beffa](//clement.beffa.org/),

Extended by [LoPablo](//github.com/LoPablo)

and [artginzburg](//github.com/artginzburg) (it's me)

  </blockquote>
</details>
