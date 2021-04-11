
A fork of [GNOME Mines](https://github.com/GNOME/gnome-mines) that's smart enough to figure out the basic logic for you.

Using two simple rules, Smart Mines is able to solve a large amount of a given minefield automatically. The two rules are:

1. If a tile is adjacent to _n_ mines, and is adjacent to exactly _n_ uncleared tiles, flag all of those tiles.
2. If a tile is adjacent to _n_ mines, and is adjacent to _n_ flags, clear all the adjacent unflagged tiles.

Simple, right? It's surprisingly effective.

Before these rules, GNOME Mines worked like this:

![Gnome-Mines](https://user-images.githubusercontent.com/6445061/114312719-a9056200-9ac1-11eb-9492-2aada03b88fd.gif)

Now, the AI turns it into:

![Smart-Mines](https://user-images.githubusercontent.com/6445061/114312720-a9056200-9ac1-11eb-989b-9ac5f58152c6.gif)

Use gnome-builder to compile and build this project.
