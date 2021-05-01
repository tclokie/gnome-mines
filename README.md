
A fork of [GNOME Mines](https://github.com/GNOME/gnome-mines) that's smart enough to figure out the basic logic for you.

Using two simple rules, Smart Mines is able to solve a large amount of a given minefield automatically. The two rules are:

1. If a tile is adjacent to _n_ mines, and is adjacent to exactly _n_ uncleared tiles, flag all of those tiles.
2. If a tile is adjacent to _n_ mines, and is adjacent to _n_ flags, clear all the adjacent unflagged tiles.

Simple, right? It's surprisingly effective.

Before these rules, GNOME Mines worked like this:

![Gnome-Mines](https://user-images.githubusercontent.com/6445061/116791149-69a9b000-aa86-11eb-929d-b88d05874266.gif)




Now, the AI turns it into:

![Smart-Mines](https://user-images.githubusercontent.com/6445061/116791151-6ca4a080-aa86-11eb-9c03-13150ff7bbc8.gif)

Use gnome-builder to compile and build this project.
