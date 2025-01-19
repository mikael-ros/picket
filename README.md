<p align="center">
	<img style="background-color: transparent" src="assets/picket_wide_logo.svg">
</p>

---

A simple fence plugin for [Godot Engine](https://godotengine.org/) 4.x. **Makes the building of fences easy, and dynamic.**

![GIF of painting a P in Picket]()

<a href='https://ko-fi.com/Z8Z212GZR6' target='_blank'><img height='60' style='border:0px;height:60px;' src='https://storage.ko-fi.com/cdn/kofi1.png?v=3' border='0' alt='Buy Me a Coffee at ko-fi.com' /></a>

## 🤔 The why?

I created this plugin for use in a small game project I'm working on. I wanted to have a simple and flexible solution for drawing fences that autoconnect, and could not find any current solutions. Such solutions may exist, but Google (as usual these days) failed me, so I decided to implement it myself. *If anything, I learnt something from it :)*

## ⚙️ Installation
### 💚 Easy
This will be the easiest method, if you don't mind updating manually
1. Download [the latest release](https://github.com/mikael-ros/picket/releases)
2. Open or extract the ``.zip``
3. Copy folder to the ``/addons/`` folder of your Godot project
> [!CAUTION]
> Make sure to preserve parent directory. Path should be ``/addons/Picket``, or similar
4. In the Godot Editor, click ``Project`` -> ``Project Settings`` -> ``Plugins`` -> Click the ``Enable`` tick next to the **Picket** plugin

### 🧠 Advanced, but flexible
> [!WARNING]
> I cannot guarantee the below working as expected, I have only recently began utilizing this methodology
During development of this addon, I utilized a slightly advanced function within [git](https://git-scm.com/), [submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules). The benefit of this, I believe, is that you can simply ``git submodule update --remote`` to fetch upstream changes.
1. In your project directory, ``git init``, if you do not already have a git repository
2. Create the ``/addons/Picket/`` directory
3. Execute ``git submodule add git@github.com:mikael-ros/picket.git /addons/Picket``
4. In the Godot Editor, click ``Project`` -> ``Project Settings`` -> ``Plugins`` -> Click the ``Enable`` tick next to the **Picket** plugin

## 🛠️ Usage
### 🖼️ Texture
> [!NOTE]
> This plugin has only been developed with 1:1 aspect ratio in mind. Other ratios may work, but is currently not officially supported

This plugin uses two separate textures; one for your fence, and one for the posts. 

#### Post texture
Post should be centered in the middle of it's texture, but can be of any size you like.

![Example post texture]()

#### Fence texture
Should be centered vertically, and should take up the width of the texture.

![Example fence texture]()

### ⚡ Minimal setup
1. Add the ``Picket`` node to your scene
	![GIF of adding Picket to scene]()
2. Add a [``TileSet``](https://docs.godotengine.org/en/stable/classes/class_tileset.html) in the properties of ``Picket``
	![GIF of adding tile set]()
3. In the *"Tile Set"* tab, add the two textures. Ideally, fence first, post second
	> note: if textures are not in that order, change the indices in the *"Texture positions"* tab of ``Picket``.
	![GIF of adding tile set textures]()
4. In the *"Tile Map"* tab, paint nodes as you normally would, but only use the post to draw
	![GIF of painting fence]()

### ✨ Advanced features
#### ⚓ Anchors
You can adjust the position at which the fences intersect. This shifts the position, and can be useful if you want to have padding. 

![How anchors affect the intersection]()

> [!TIP]
> If you stil want to adjust the position manually, use the *"Origin"* positions. Any adjustment of the normal *"Position"* vector will be overwritten otherwise.

#### 📍 Offset
You can adjust where in the tile the posts are placed. The addon will dynamically fill in posts where absent, so spacing is consistent.

#### 📏 Spacing
You can adjust the spacing by which posts are placed. 

> [!NOTE]
> You can not affect the position by intersections, these are locked for realism reasons.

> [!WARN]
> Not yet implemented

### 🧩 Current limitations and feature suggestions
Currently, tile shapes are not supported beyond *"Square"*. Non-uniform fences aren't supported yet either, so fences can only be straight.

If you desire certain functionality within this plugin, or encounter a bug, feel free to [add an issue](https://github.com/mikael-ros/picket/issues/new) and I will get around to it when time allows - or you can contribute it yourself, see the [contribution guidelines](/CONTRIBUTING.md) 


## 💾 Short technical description
This plugin reads the tile map data, and paints two offset child [``TileMapLayer``](https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html)s with the fence texture - one for vertical connections, and one for horizontal connections. 

For more technical details, read the code contained in this repository.
