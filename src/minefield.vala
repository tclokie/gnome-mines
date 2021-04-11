/*
 * Copyright (C) 2011-2012 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public enum FlagType
{
    NONE,
    FLAG,
    MAYBE
}

protected class Location : Object
{
    /* true if contains a mine */
    public bool has_mine = false;

    /* true if cleared */
    public bool cleared = false;

    /* Flag */
    public FlagType flag = FlagType.NONE;

    /* Number of mines in the neighbourhood */
    public int adjacent_mines = 0;

    /* For AI use only */
    public bool to_explore = false;
}

/* Table of offsets to adjacent squares */
private struct Neighbour
{
    public int x;
    public int y;
}
private const Neighbour neighbour_map[] =
{
    { -1,  1 },
    {  0,  1 },
    {  1,  1 },
    {  1,  0 },
    {  1, -1 },
    {  0, -1 },
    { -1, -1 },
    { -1,  0 }
};

public struct Coordinate
{
    public uint x;
    public uint y;
}

public class Minefield : Object
{
    /* Size of map */
    public uint width = 0;
    public uint height = 0;

    /* Number of mines in map */
    public uint n_mines = 0;

    /* State of each location */
    protected Location[,] locations;

    /* true if have hit a mine */
    public bool exploded = false;

    /* true if have placed the mines onto the map */
    protected bool placed_mines = false;

    /* keep track of flags and cleared squares */
    private uint _n_cleared = 0;
    private uint _n_flags = 0;

    protected bool _use_autoflag;

    public uint n_cleared
    {
        get { return _n_cleared; }
    }

    public bool is_complete
    {
        get { return _n_cleared == width * height - n_mines; }
    }

    public uint n_flags
    {
        get { return _n_flags; }
    }

    public bool use_autoflag
    {
        get { return _use_autoflag; }
        set { _use_autoflag = value; }
    }

    /* Game timer */
    private double clock_elapsed;
    private Timer? clock;
    private uint clock_timeout;

    public double elapsed
    {
        get
        {
            return clock_elapsed + (clock == null ? 0.0 : clock.elapsed ());
        }
    }

    private bool _paused = false;
    public bool paused
    {
        set
        {
            if (is_complete || exploded)
                return;

            if (value && !_paused)
                stop_clock ();
            else if (!value && _paused)
                continue_clock ();

            _paused = value;
            paused_changed ();
        }
        get { return _paused; }
    }

    public signal void clock_started ();
    public signal void paused_changed ();
    public signal void tick ();

    public signal void redraw_sector (uint x, uint y);

    public signal void marks_changed ();
    public signal void explode ();
    public signal void cleared ();

    public Minefield (uint width, uint height, uint n_mines)
    {
        locations = new Location[width, height];
        for (var x = 0; x < width; x++)
            for (var y = 0; y < height; y++)
                locations[x, y] = new Location ();
        this.width = width;
        this.height = height;
        this.n_mines = n_mines;
    }

    public bool is_clock_started ()
    {
        return elapsed > 0;
    }

    public bool has_mine (uint x, uint y)
    {
        return locations[x, y].has_mine;
    }

    public bool is_cleared (uint x, uint y)
    {
        return locations[x, y].cleared;
    }

    public bool is_location (int x, int y)
    {
        return x >= 0 && y >= 0 && x < width && y < height;
    }

    public void multi_release (uint x, uint y)
    {
        if (!is_cleared (x, y) || get_flag (x, y) == FlagType.FLAG)
            return;

        /* Work out how many flags / unknown squares surround this one */
        var n_mines = get_n_adjacent_mines (x, y);
        uint n_flags = 0;
        uint n_unknown = 0;
        foreach (var neighbour in neighbour_map)
        {
            var nx = (int) x + neighbour.x;
            var ny = (int) y + neighbour.y;
            if (!is_location (nx, ny))
                continue;
            if (get_flag (nx, ny) == FlagType.FLAG)
                n_flags++;
            if (!is_cleared (nx, ny))
                n_unknown++;
        }

        /* If have correct number of flags to mines then clear the other
         * locations, otherwise if the number of unknown squares is the
         * same as the number of mines flag them all */
        var do_clear = false;
        if (n_mines == n_flags)
            do_clear = true;
        else if (use_autoflag && n_unknown == n_mines)
            do_clear = false;
        else
            return;

        /* Use the same minefield for the whole time (it may complete as we do it) */

        foreach (var neighbour in neighbour_map)
        {
            var nx = (int) x + neighbour.x;
            var ny = (int) y + neighbour.y;
            if (!is_location (nx, ny))
                continue;

            if (do_clear && get_flag (nx, ny) != FlagType.FLAG){
                clear_mine (nx, ny);
                if (clock == null)
                    return;
            } else {
                set_flag (nx, ny, FlagType.FLAG);
            }
        }
    }

    public void clear_mine (uint x, uint y)
    {
        /* Place mines on first attempt to clear */
        if (!placed_mines)
        {
            place_mines (x, y);
            placed_mines = true;
        }

        if (!exploded && clock == null)
            start_clock ();

        if (locations[x, y].cleared || locations[x, y].flag == FlagType.FLAG)
            return;

        if (!attempt_clear(x, y))
            return;

        work_on_neighbours(x, y);
        foreach (var neighbour in neighbour_map)
        {
            var nx = (int) x + neighbour.x;
            var ny = (int) y + neighbour.y;
            if (is_location(nx, ny))
                work_on_neighbours(nx, ny);
        }

        /* Failed if this contained a mine */
        if (locations[x, y].has_mine)
        {
            if (!exploded)
            {
                exploded = true;
                stop_clock ();
                explode ();
            }
            return;
        }

        /* Mark unmarked mines when won */
        if (is_complete && !exploded)
        {
            stop_clock ();
            for (var tx = 0; tx < width; tx++)
                for (var ty = 0; ty < height; ty++)
                    if (has_mine (tx, ty))
                        set_flag (tx, ty, FlagType.FLAG);
            cleared ();
        }
    }

    private bool attempt_clear (uint x, uint y)
    {
        if (locations[x, y].cleared)
            return false;

        locations[x, y].cleared = true;
        _n_cleared++;
        if (locations[x, y].flag == FlagType.FLAG)
            _n_flags--;
        locations[x, y].flag = FlagType.NONE;
        redraw_sector (x, y);
        marks_changed ();
        return true;
    }

    private void work_on_neighbours (uint x, uint y)
    {
        Queue<Coordinate?> to_explore = new Queue<Coordinate?> ();
        to_explore.push_tail({x, y});
        locations[x, y].to_explore = true;

        while (!to_explore.is_empty())
        {
            bool changed = false;
            Coordinate c = to_explore.pop_tail();
            x = c.x;
            y = c.y;

            if (!locations[x, y].has_mine && get_n_adjacent_mines (x, y) == get_n_uncleared_neighbours (x, y))
            {
                foreach (var neighbour in neighbour_map)
                {
                    var nx = (int) x + neighbour.x;
                    var ny = (int) y + neighbour.y;
                    if (is_location (nx, ny) && !is_cleared (nx, ny) && get_flag(nx, ny) != FlagType.FLAG)
                    {
                        set_flag (nx, ny, FlagType.FLAG);
                        changed = true;
                        if (!locations[nx, ny].to_explore)
                        {
                            to_explore.push_tail({nx, ny});
                            locations[nx, ny].to_explore = true;
                        }
                        foreach (var second_neighbour in neighbour_map)
                        {
                            var nnx = (int) nx + second_neighbour.x;
                            var nny = (int) ny + second_neighbour.y;
                            if (is_location (nnx, nny) && !locations[nnx, nny].to_explore)
                            {
                                to_explore.push_tail({nnx, nny});
                                locations[nnx, nny].to_explore = true;
                            }
                        }
                    }
                }
            }

            // Automatically clear locations if no adjacent mines
            else if (!locations[x, y].has_mine && get_n_adjacent_mines (x, y) == get_n_flagged_neighbours (x, y))
            {
                foreach (var neighbour in neighbour_map)
                {
                    var nx = (int) x + neighbour.x;
                    var ny = (int) y + neighbour.y;
                    if (is_location (nx, ny) && get_flag(nx, ny) != FlagType.FLAG && attempt_clear(nx, ny))
                    {
                        changed = true;
                        if (!locations[nx, ny].to_explore)
                        {
                            to_explore.push_tail({nx, ny});
                            locations[nx, ny].to_explore = true;
                        }
                        foreach (var second_neighbour in neighbour_map)
                        {
                            var nnx = (int) nx + second_neighbour.x;
                            var nny = (int) ny + second_neighbour.y;
                            if (is_location (nnx, nny) && !locations[nnx, nny].to_explore)
                            {
                                to_explore.push_tail({nnx, nny});
                                locations[nnx, nny].to_explore = true;
                            }
                        }
                    }
                }
            }

            locations[x, y].to_explore = false;

            if (changed)
            {
                foreach (var neighbour in neighbour_map)
                {
                    var nx = (int) x + neighbour.x;
                    var ny = (int) y + neighbour.y;
                    if (is_location (nx, ny) && get_flag(nx, ny) != FlagType.FLAG)
                    {
                        if (!locations[nx, ny].to_explore)
                        {
                            to_explore.push_tail({nx, ny});
                            locations[nx, ny].to_explore = true;
                        }
                    }
                }
            }
        }
    }

    private uint get_n_uncleared_neighbours (uint x, uint y)
    {
        var count = 0;
        foreach (var neighbour in neighbour_map)
        {
            var nx = (int) x + neighbour.x;
            var ny = (int) y + neighbour.y;
            if (is_location (nx, ny) && !is_cleared(nx, ny))
                count += 1;
        }
        return count;
    }

    private uint get_n_flagged_neighbours (uint x, uint y)
    {
        var count = 0;
        foreach (var neighbour in neighbour_map)
        {
            var nx = (int) x + neighbour.x;
            var ny = (int) y + neighbour.y;
            if (is_location (nx, ny) && !is_cleared(nx, ny) && get_flag(nx, ny) == FlagType.FLAG)
                count += 1;
        }
        return count;
    }

    private bool has_unknown_neighbours (uint x, uint y)
    {
        foreach (var neighbour in neighbour_map)
        {
            var nx = (int) x + neighbour.x;
            var ny = (int) y + neighbour.y;
            if (is_location (nx, ny) && !is_cleared(nx, ny) && get_flag(nx,ny) != FlagType.FLAG)
                return true;
        }
        return false;
    }

    public void set_flag (uint x, uint y, FlagType flag)
    {
        if (locations[x, y].cleared || locations[x, y].flag == flag)
            return;

        if (flag == FlagType.FLAG)
            _n_flags++;
        else if (locations[x, y].flag == FlagType.FLAG)
            _n_flags--;

        locations[x, y].flag = flag;
        redraw_sector (x, y);
        marks_changed ();

    }

    public FlagType get_flag (uint x, uint y)
    {
        return locations[x, y].flag;
    }

    public uint get_n_adjacent_mines (uint x, uint y)
    {
        return locations[x, y].adjacent_mines;
    }

    public bool has_flag_warning (uint x, uint y)
    {
        if (!is_cleared (x, y))
            return false;

        uint n_mines = 0, n_flags = 0;
        foreach (var neighbour in neighbour_map)
        {
            var nx = (int) x + neighbour.x;
            var ny = (int) y + neighbour.y;
            if (!is_location (nx, ny))
                continue;
            if (has_mine (nx, ny))
                n_mines++;
            if (get_flag (nx, ny) == FlagType.FLAG)
                n_flags++;
        }

        return n_flags > n_mines;
    }

    /* Randomly set the mines, but avoid the current and adjacent locations */
    private void place_mines (uint x, uint y)
    {
        for (var n = 0; n < n_mines;)
        {
            var rx = Random.int_range (0, (int32) width);
            var ry = Random.int_range (0, (int32) height);

            if (rx == x && ry == y)
                continue;

            if (!locations[rx, ry].has_mine)
            {
                var adj_found = false;

                foreach (var neighbour in neighbour_map)
                {
                    if (rx == x + neighbour.x && ry == y + neighbour.y)
                    {
                        adj_found = true;
                        break;
                    }
                }

                if (!adj_found)
                {
                    locations[rx, ry].has_mine = true;
                    n++;
                    foreach (var neighbour in neighbour_map)
                    {
                        var nx = rx + neighbour.x;
                        var ny = ry + neighbour.y;
                        if (is_location (nx, ny))
                            locations[nx, ny].adjacent_mines++;
                    }
                }
            }
        }
    }

    private void start_timer ()
    {
        if (clock_timeout != 0)
            Source.remove (clock_timeout);
        clock_timeout = 0;
        clock_timeout = Timeout.add (500, timeout_cb);
    }

    private void start_clock ()
    {
        if (clock == null)
            clock = new Timer ();
        clock_started ();
        tick ();
        start_timer ();
    }

    private void stop_clock ()
    {
        if (clock == null)
            return;
        clock_elapsed += clock.elapsed ();
        if (clock_timeout != 0)
            Source.remove (clock_timeout);
        clock_timeout = 0;
        clock.stop ();
        clock = null;
        tick ();
    }

    private void continue_clock ()
    {
        if (clock == null)
            clock = new Timer ();
        else
            clock.continue ();
        tick ();
        start_timer ();
    }

    private bool timeout_cb ()
    {
        tick ();
        return true;
    }
}
