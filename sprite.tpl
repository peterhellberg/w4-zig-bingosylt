{{#sprites}}
pub const {{name}} = Sprite{
    .sprite = ([{{length}}]u8{ {{bytes}} })[0..],
    .width = {{width}},
    .height = {{height}},
    .flags = w4.{{flagsHumanReadable}},
};
{{/sprites}}
