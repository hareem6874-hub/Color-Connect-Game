# Color Connect

A colorful 5×5 puzzle game written in **8086 assembly**, using **NASM** and running in **DOSBox**. Connect five matching pairs without crossing paths before the 30-second countdown reaches zero.

Developed as a Computer Organization and Assembly Language (COAL) project. Submission ID: **25L-2536**.

## Features

- Three levels, each with five colored pairs. Levels 2 and 3 are rotated versions of the first puzzle.
- Graphics with circular endpoints, thick paths, a grid, and a highlighted cursor.
- An “Are You Ready?” screen with a keyboard-operated Start button.
- A 30-second countdown for each level.
- Score, move count, level indicator, and completed-pair counter.
- Undo, path editing, and level reset.
- A “Time Over” screen on timeout and a final win screen after completing all levels.
- A keyboard-operated Restart button on both end screens.
- Incremental drawing to reduce flicker during play.
- One self-contained assembly source file; no external assets or libraries.

## Requirements

- **NASM** to assemble the source on your host computer.
- **DOSBox** to run the resulting DOS `.COM` program.

## Build

Open a terminal in the folder containing `25L-2536bonus.asm` and run:

```text
nasm -f bin 25L-2536bonus.asm -o BONUS.com
```

If NASM is not on your PATH, use the full path to its executable. For example, in Windows PowerShell:

```powershell
& "C:\assembly\Assembly Programming Tools\assemblytools\nasm-2.16.01\nasm.exe" -f bin 25L-2536bonus.asm -o BONUS.com
```

Run the Windows NASM executable in your Windows terminal. After assembly, run `BONUS.com` in DOSBox.

## Run in DOSBox

Place `BONUS.com` in a folder such as `C:\Color-Connect-Game`. Open DOSBox and enter these commands one at a time:

```dos
mount c "C:\Color-Connect-Game"
c:
color.com
```

Replace the example path with your actual game folder. If DOSBox drive C is already mounted to that folder, skip the mount command.

## How to Play

1. Press **Enter** or **Space** on the welcome screen to start.
2. Move the white cursor to a colored endpoint using the arrow keys.
3. Press **Space** to select that color.
4. Use the arrow keys to extend a path to its matching endpoint.
5. Connect all five pairs within **30 seconds**. Paths cannot cross or enter another color's endpoint. Filling every cell is optional.
6. After solving levels 1 and 2, press **N** to continue. The timer pauses while the solved level waits.
7. Completing level 3 shows the final win screen. Running out of time ends the game.

## Controls

| Key | Action |
| --- | --- |
| Enter / Space | Start from the welcome screen |
| Arrow keys | Move the cursor or extend the selected path |
| Space | Select a color from either endpoint |
| U / Backspace | Undo one step; at the starting endpoint, cancel selection |
| R | Reset the current level and its timer |
| N | Advance after solving a level |
| Enter / R | Restart the entire game from an end screen |
| Esc | Exit to DOS |

Moving back into the previous path cell also undoes the last step. To edit an earlier path, select one of its endpoints with **Space**, then press **U**. Start and Restart buttons are operated with the keyboard.

## Score and Timer

- Each completed pair earns **100 points**.
- Each earlier solved level contributes **500 points** to the score.
- The maximum score is **1,500 points** after all three levels.
- Undoing a completed pair removes its 100 points.
- Resetting a level clears its points, moves, and countdown while preserving credit for earlier solved levels.
- Moves count accepted path extensions, including segments drawn again after undo.
- Each level begins at **00:30**. The clock stays paused on the welcome screen and after solving a level.
- Restart returns to level 1 and clears all progress.

## Assembly Concepts Used

| Concept | Purpose |
| --- | --- |
| BIOS video interrupt `INT 10h` | Set graphics mode, draw pixels, and display text |
| BIOS keyboard interrupt `INT 16h` | Read keys and check for input while updating the countdown |
| Timer interrupt `INT 08h` | Maintain the countdown using approximately 18.2 timer ticks per second |
| Interrupt Vector Table | Install the timer handler, save the original handler, and restore it on normal exit |
| DOS interrupt `INT 21h` | Terminate the program |
| Arrays and indexed addressing | Store endpoints, board occupancy, path history, and completion flags |
| Stack instructions `PUSH` / `POP` | Preserve register values |
| Procedures `CALL` / `RET` | Organize drawing, game logic, input, and timing |
| Arithmetic and conditional jumps | Calculate positions and scores, validate moves, and detect wins or timeout |
| String instructions | Initialize arrays, copy level data, and read text |

The program uses **320×200, 16-color BIOS graphics mode 0Dh**. Rectangles and short horizontal-strip tables form the paths and circular endpoints. Graphics are drawn through BIOS services rather than direct writes to video memory.

The timer handler updates counters without calling video or DOS services, chains the original BIOS handler, and restores the original interrupt vector before normal exit. The countdown uses an approximate rate of **18.2 ticks per second**.

## Source File

```text
25L-2536bonus.asm    Complete game source
```

The source includes `[cpu 8086]` to restrict instructions to the 8086 and `[org 100h]` for the DOS `.COM` program layout.

## Validation

The source has been assembled successfully with NASM for the 8086 target, with warnings treated as errors. Static checks covered puzzle solutions, drawing coordinates, timer arithmetic, and game-state transitions. Interactive DOSBox gameplay has not yet been verified as part of these checks.
