A fork of [GNOME Mines](https://github.com/GNOME/gnome-mines) that's smart enough to figure out the basic logic for you.

Using two simple rules, Smart Mines is able to solve a large amount of a given minefield automatically. The two rules are:

1. If a tile is adjacent to _n_ mines, and is adjacent to exactly _n_ uncleared tiles, flag all of those tiles.
2. If a tile is adjacent to _n_ mines, and is adjacent to _n_ flags, clear all the adjacent unflagged tiles.

Simple, right? It's surprisingly effective.

Before these rules, GNOME Mines worked like this:

https://user-images.githubusercontent.com/6445061/114310552-16f95b80-9ab9-11eb-8059-cb1165f81d00.mp4

Now, the AI turns it into:

https://user-images.githubusercontent.com/6445061/114310556-1b257900-9ab9-11eb-9df1-5f5831d79480.mp4

Use gnome-builder to compile and build this project.
