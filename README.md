# w4-zig-bingosylt :zap:

A game written in Zig for the [WASM-4](https://wasm4.org) fantasy console.

<img src="https://i.imgur.com/VU2HYxl.png" width="320">

## Building

Build the cart by running:

```shell
make
```

Then run it with:

```shell
make run
```

Bundle for html, linux and windows using:

```shell
make bundle
```

## Sprites

I generate sprites from PNG files like this `w4 png2src -t sprite.tpl image.png`

Where the custom template for `w4 png2src` looks like this:
```zig
{{#sprites}}
pub const {{name}} = Sprite{
    .sprite = ([{{length}}]u8{ {{bytes}} })[0..],
    .width = {{width}},
    .height = {{height}},
    .flags = {{flags}}, // {{flagsHumanReadable}}
};
{{/sprites}}
```


## Links

- :art: [Lospec Pixel Art Scaler](https://lospec.com/pixel-art-scaler/): This tools helps you scale pixel art to bigger sizes without filtering
- :tangerine: [Lospec Tangerine Noir Palette](https://lospec.com/palette-list/tangerine-noir): Three shades with a sharp tangerine accent
- :video_game: [WASM-4 Documentation](https://wasm4.org/docs): Learn more about WASM-4
- :octocat: [WASM-4 GitHub](https://github.com/aduros/wasm4): Submit an issue or PR. Contributions are welcome!
- :sparkles: [Jok](https://github.com/Jack-Ji/jok): A minimal 2d/3d game framework for Zig
- :fire: [Zig Crash Course](https://ikrima.dev/dev-notes/zig/zig-crash-course/)

## Jam

Kodsnacks Tvåveckorssylt - #9
<https://itch.io/jam/spelsylt9>

> [!IMPORTANT]
> Submissions open to November 6th 2023 at 12:00 AM

### Theme: BINGO!

Skapa din egen bingorad från bingobrickan nedanför. Du måste välja minst 2 rutor och de måste sitta ihop enligt klassiska bingoregler (horisontellt, vertikalt eller diagonalt).

Skriva gärna på ditt spel vilka brickor du valde!

![Bingo](https://i.imgur.com/K96Cb2N.png)
